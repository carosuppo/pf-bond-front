import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../constants/location_tracking_config.dart';
import '../models/location_model.dart';
import 'location_tracking_task_handler.dart';

abstract interface class ForegroundTaskGateway {
  Future<bool> get isRunning;
  Future<void> start();
  Future<void> stop();
  void addDataCallback(void Function(Object) callback);
  void removeDataCallback(void Function(Object) callback);
}

class FlutterForegroundTaskGateway implements ForegroundTaskGateway {
  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  @override
  Future<void> start() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 731,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Bond está compartiendo tu ubicación',
      notificationText: 'Tu ubicación se comparte con los grupos habilitados.',
      callback: startLocationTrackingCallback,
    );
    if (result is ServiceRequestFailure) throw result.error;
  }

  @override
  Future<void> stop() async {
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) throw result.error;
  }

  @override
  void addDataCallback(void Function(Object) callback) =>
      FlutterForegroundTask.addTaskDataCallback(callback);

  @override
  void removeDataCallback(void Function(Object) callback) =>
      FlutterForegroundTask.removeTaskDataCallback(callback);
}

class BackgroundLocationService {
  BackgroundLocationService({ForegroundTaskGateway? gateway})
    : _gateway = gateway ?? FlutterForegroundTaskGateway();

  final ForegroundTaskGateway _gateway;
  Future<void>? _startOperation;
  Future<void>? _stopOperation;

  static void initialize() {
    FlutterForegroundTask.initCommunicationPort();
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bond_location_tracking',
        channelName: 'Ubicación compartida de Bond',
        channelDescription:
            'Muestra cuándo Bond comparte tu ubicación en segundo plano.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          LocationTrackingConfig.heartbeatInterval.inMilliseconds,
        ),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  Future<bool> get isRunning => _gateway.isRunning;

  Future<void> ensureRunning() {
    return _startOperation ??= _ensureRunning().whenComplete(() {
      _startOperation = null;
    });
  }

  Future<void> _ensureRunning() async {
    final stopOperation = _stopOperation;
    if (stopOperation != null) await stopOperation;
    if (await _gateway.isRunning) return;
    await _gateway.start();
  }

  Future<void> stop() {
    return _stopOperation ??= _stop().whenComplete(() {
      _stopOperation = null;
    });
  }

  Future<void> _stop() async {
    final startOperation = _startOperation;
    if (startOperation != null) {
      try {
        await startOperation;
      } catch (_) {
        // A failed start leaves nothing to stop.
      }
    }
    if (!await _gateway.isRunning) return;
    await _gateway.stop();
  }

  void addLocationListener(void Function(LocationModel) listener) {
    void callback(Object data) {
      if (data is! Map || data['type'] != 'location') return;
      final timestamp = DateTime.tryParse(data['timestamp'] as String? ?? '');
      if (timestamp == null) return;
      listener(
        LocationModel(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          accuracy: (data['accuracy'] as num).toDouble(),
          timestamp: timestamp,
        ),
      );
    }

    _listenerCallbacks[listener] = callback;
    _gateway.addDataCallback(callback);
  }

  final Map<void Function(LocationModel), void Function(Object)>
  _listenerCallbacks = {};

  void removeLocationListener(void Function(LocationModel) listener) {
    final callback = _listenerCallbacks.remove(listener);
    if (callback != null) _gateway.removeDataCallback(callback);
  }
}
