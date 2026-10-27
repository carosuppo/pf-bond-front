import 'dart:async';
import 'dart:ui';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage_service.dart';
import '../constants/location_tracking_config.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';
import 'location_backend_service.dart';
import 'location_service.dart';

@pragma('vm:entry-point')
void startLocationTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTrackingTaskHandler());
}

class LocationTrackingTaskHandler extends TaskHandler {
  LocationTrackingTaskHandler({
    LocationService? locationService,
    LocationBackendService? backendService,
    LocationTaskRuntime? runtime,
    this.initializePlugins = true,
    SessionStorageService? sessionStorage,
  }) : _locationService = locationService ?? LocationService(),
       _backendService =
           backendService ??
           LocationBackendService(ApiClient(SessionStorageService())),
       _runtime = runtime ?? const FlutterLocationTaskRuntime(),
       _sessionStorage = sessionStorage ?? SessionStorageService();

  final LocationService _locationService;
  final LocationBackendService _backendService;
  final LocationTaskRuntime _runtime;
  final bool initializePlugins;
  final SessionStorageService _sessionStorage;
  Timer? _retryTimer;
  int _retrySeconds = 5;
  bool _connecting = false;
  bool _checking = false;
  bool _authorized = false;
  bool _sampling = false;
  bool _heartbeatInFlight = false;
  DateTime? _lastSampleAttempt;
  DateTime? _lastStreamEvent;

  StreamSubscription<LocationModel>? _positionSubscription;
  LocationModel? _lastPublishedLocation;
  DateTime? _lastPublishedAt;
  bool _publishing = false;
  bool _stopping = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (initializePlugins) {
      DartPluginRegistrant.ensureInitialized();
      await dotenv.load(fileName: '.env');
    }

    _lastStreamEvent ??= timestamp;
    await _reconcile();
    if (_authorized && !_stopping) await _samplePosition(timestamp);
  }

  // A restarted isolate obtains backend authorization before accessing GPS.
  // Offline startup remains idle and retries on the next heartbeat tick.
  Future<void> _reconcile() async {
    if (_checking || _stopping) return;
    _checking = true;
    try {
      if (await _sessionStorage.isTrackingSuspended() ||
          !await _sessionStorage.hasValidSession()) {
        await _stopAfterInvalidSession();
        return;
      }
      final permission = await _locationService.checkBackgroundPermission();
      if (_stopping) return;
      if (permission != LocationPermissionStatus.always) {
        await _stopAfterInvalidSession();
        return;
      }
      if (!_authorized) {
        final sharing = await _backendService.getSharing();
        if (_stopping) return;
        if (!sharing.any((item) => item.effectiveLocationSharing)) {
          await _stopAfterInvalidSession();
          return;
        }
        _authorized = true;
      }
      await _connectStream();
    } on ApiException catch (error) {
      if (_isTerminal(error)) await _stopAfterInvalidSession();
    } catch (_) {
      // Storage, GPS and network can be temporarily unavailable at boot.
    } finally {
      _checking = false;
    }
  }

  Future<void> _connectStream() async {
    if (_stopping ||
        !_authorized ||
        _connecting ||
        _positionSubscription != null ||
        _retryTimer != null) {
      return;
    }
    _connecting = true;
    try {
      _positionSubscription = _locationService
          .getBackgroundLocationStream()
          .listen(
            (location) {
              _lastStreamEvent = DateTime.now();
              _retrySeconds = 5;
              unawaited(_handleLocation(location));
            },
            onError: (Object error) => unawaited(_recoverStream()),
            onDone: () => unawaited(_recoverStream()),
          );
    } catch (_) {
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _recoverStream() async {
    if (_stopping || _connecting || _retryTimer != null) return;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _connecting = true;
    try {
      await subscription?.cancel();
    } catch (_) {
      // A failed cancellation must not suppress recovery.
    } finally {
      _connecting = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_stopping || _retryTimer != null) return;
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      _retryTimer = null;
      unawaited(_reconcile());
    });
    _retrySeconds = (_retrySeconds * 2).clamp(5, 120);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_repeat(timestamp));
  }

  Future<void> _repeat(DateTime timestamp) async {
    await _reconcile();
    if (_stopping || !_authorized) return;
    unawaited(_sendHeartbeat());
    await _samplePosition(timestamp);
  }

  Future<void> _samplePosition(DateTime now) async {
    if (_stopping || !_authorized || _sampling) return;
    if (_lastSampleAttempt != null &&
        now.difference(_lastSampleAttempt!) <
            LocationTrackingConfig.fallbackInterval) {
      return;
    }
    _sampling = true;
    _lastSampleAttempt = now;
    try {
      if (_lastStreamEvent != null &&
          _positionSubscription != null &&
          now.difference(_lastStreamEvent!) >=
              LocationTrackingConfig.fallbackInterval) {
        _lastStreamEvent = now;
        await _recoverStream();
        if (_stopping) return;
      }
      final location = await _locationService.getCurrentBackgroundLocation();
      if (!_stopping) await _handleLocation(location);
    } catch (_) {
      // The next spaced attempt retries; heartbeat remains independent.
    } finally {
      _sampling = false;
    }
  }

  bool _isTerminal(ApiException error) =>
      error.isUnauthorized ||
      (error.statusCode == 403 &&
          error.message ==
              'No groups have effective location sharing enabled.');

  Future<void> _handleLocation(
    LocationModel location, {
    bool force = false,
  }) async {
    if (_stopping || !_authorized) return;
    _runtime.sendDataToMain(<String, Object>{
      'type': 'location',
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
      'timestamp': location.timestamp.toUtc().toIso8601String(),
    });

    final now = DateTime.now();
    final enoughTime =
        _lastPublishedAt == null ||
        now.difference(_lastPublishedAt!) >=
            LocationTrackingConfig.minimumPublishInterval;
    final enoughDistance =
        _lastPublishedLocation == null ||
        _locationService.distanceBetween(_lastPublishedLocation!, location) >=
            LocationTrackingConfig.minimumPublishDistanceMeters;

    if (_publishing || (!force && (!enoughTime || !enoughDistance))) return;

    _publishing = true;
    try {
      await _backendService.publishCurrentLocation(location);
      _lastPublishedLocation = location;
      _lastPublishedAt = now;
    } on ApiException catch (error) {
      if (_isTerminal(error)) await _stopAfterInvalidSession();
    } catch (_) {
      // Connectivity failures do not stop tracking. A later sample retries.
    } finally {
      _publishing = false;
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_stopping || !_authorized || _heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      await _backendService.sendHeartbeat();
    } on ApiException catch (error) {
      if (_isTerminal(error)) await _stopAfterInvalidSession();
    } catch (_) {
      // Connectivity failures are retried at the next heartbeat.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> _stopAfterInvalidSession() async {
    if (_stopping) return;
    _stopping = true;
    _authorized = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    try {
      await subscription?.cancel();
    } finally {
      await _runtime.stopService();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _stopping = true;
    _authorized = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

abstract interface class LocationTaskRuntime {
  void sendDataToMain(Object data);
  Future<void> stopService();
}

class FlutterLocationTaskRuntime implements LocationTaskRuntime {
  const FlutterLocationTaskRuntime();

  @override
  void sendDataToMain(Object data) =>
      FlutterForegroundTask.sendDataToMain(data);

  @override
  Future<void> stopService() async {
    await SessionStorageService().setTrackingSuspended(true);
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) throw result.error;
  }
}
