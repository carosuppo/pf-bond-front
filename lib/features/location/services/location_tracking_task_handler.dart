import 'dart:async';
import 'dart:ui';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage_service.dart';
import '../constants/location_tracking_config.dart';
import '../models/location_model.dart';
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
  }) : _locationService = locationService ?? LocationService(),
       _backendService =
           backendService ??
           LocationBackendService(ApiClient(SessionStorageService())),
       _runtime = runtime ?? const FlutterLocationTaskRuntime();

  final LocationService _locationService;
  final LocationBackendService _backendService;
  final LocationTaskRuntime _runtime;
  final bool initializePlugins;

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

    _positionSubscription ??= _locationService.getLocationStream().listen(
      (location) => unawaited(_handleLocation(location)),
      onError: (_) {
        // A stream error is transient. Android keeps the foreground service
        // alive and the plugin may restart it if the process is reclaimed.
      },
    );

    try {
      await _handleLocation(
        await _locationService.getCurrentLocation(),
        force: true,
      );
    } catch (_) {
      // GPS/network may be temporarily unavailable; the stream retries later.
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_sendHeartbeat());
  }

  Future<void> _handleLocation(
    LocationModel location, {
    bool force = false,
  }) async {
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
      if (error.isUnauthorized) await _stopAfterInvalidSession();
    } catch (_) {
      // Connectivity failures do not stop tracking. A later sample retries.
    } finally {
      _publishing = false;
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_stopping) return;
    try {
      await _backendService.sendHeartbeat();
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _stopAfterInvalidSession();
    } catch (_) {
      // Connectivity failures are retried at the next heartbeat.
    }
  }

  Future<void> _stopAfterInvalidSession() async {
    if (_stopping) return;
    _stopping = true;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _runtime.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _stopping = true;
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
    await FlutterForegroundTask.stopService();
  }
}
