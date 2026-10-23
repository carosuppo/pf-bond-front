import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/services/location_backend_service.dart';
import 'package:bond_front/features/location/services/location_service.dart';
import 'package:bond_front/features/location/services/location_tracking_task_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService extends LocationService {
  final positions = StreamController<LocationModel>.broadcast();
  int streams = 0;
  int samples = 0;
  LocationPermissionStatus permission = LocationPermissionStatus.always;
  Completer<LocationModel>? sampleBarrier;
  @override
  Future<LocationPermissionStatus> checkBackgroundPermission() async =>
      permission;
  final current = LocationModel(
    latitude: -34.6,
    longitude: -58.4,
    accuracy: 4,
    timestamp: DateTime.utc(2026, 9, 4),
  );

  @override
  Future<LocationModel> getCurrentBackgroundLocation() async {
    samples++;
    return sampleBarrier == null ? current : sampleBarrier!.future;
  }

  @override
  Stream<LocationModel> getBackgroundLocationStream() {
    streams++;
    return positions.stream;
  }

  @override
  double distanceBetween(LocationModel first, LocationModel second) => 100;
}

class _FakeBackend extends LocationBackendService {
  _FakeBackend() : super(ApiClient(SessionStorageService()));

  bool sharingEnabled = true;
  Object? sharingError;
  @override
  Future<List<LocationSharingModel>> getSharing() async {
    if (sharingError case final error?) throw error;
    return sharingEnabled
        ? const [
            LocationSharingModel(
              memberId: 1,
              groupId: 1,
              locationSharingEnabled: true,
              shareLocationMandatorily: false,
              effectiveLocationSharing: true,
            ),
          ]
        : [];
  }

  int publications = 0;
  int heartbeats = 0;
  Object? publishError;
  Object? heartbeatError;

  @override
  Future<void> publishCurrentLocation(LocationModel location) async {
    publications++;
    if (publishError case final error?) throw error;
  }

  @override
  Future<void> sendHeartbeat() async {
    heartbeats++;
    if (heartbeatError case final error?) throw error;
  }
}

class _Session extends SessionStorageService {
  bool valid = true;
  bool suspended = false;
  @override
  Future<bool> hasValidSession() async => valid;
  @override
  Future<bool> isTrackingSuspended() async => suspended;
}

class _FakeRuntime implements LocationTaskRuntime {
  final sent = <Object>[];
  int stops = 0;

  @override
  void sendDataToMain(Object data) => sent.add(data);

  @override
  Future<void> stopService() async => stops++;
}

Future<LocationTrackingTaskHandler> _startHandler({
  required _FakeLocationService location,
  required _FakeBackend backend,
  required _FakeRuntime runtime,
}) async {
  final handler = LocationTrackingTaskHandler(
    locationService: location,
    backendService: backend,
    runtime: runtime,
    initializePlugins: false,
    sessionStorage: _Session(),
  );
  await handler.onStart(DateTime.now(), TaskStarter.developer);
  return handler;
}

void main() {
  for (final done in [false, true]) {
    test('stream recovery (done=$done) cancels retries on destroy', () async {
      final location = _FakeLocationService();
      final backend = _FakeBackend();
      final runtime = _FakeRuntime();
      final handler = await _startHandler(
        location: location,
        backend: backend,
        runtime: runtime,
      );
      if (done) {
        unawaited(location.positions.close());
      } else {
        location.positions.addError(Exception('GPS off'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(location.positions.hasListener, isFalse);
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(location.streams, 1);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(location.streams, 2);
      await handler.onDestroy(DateTime.now(), false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(location.streams, 2);
      await location.positions.close();
    });
  }

  test(
    'fallback is spaced, non-overlapping and GPS failure preserves heartbeat',
    () async {
      final location = _FakeLocationService();
      final backend = _FakeBackend();
      final runtime = _FakeRuntime();
      final handler = await _startHandler(
        location: location,
        backend: backend,
        runtime: runtime,
      );
      final now = DateTime.now();
      handler.onRepeatEvent(now);
      await Future<void>.delayed(Duration.zero);
      expect(location.samples, 1);
      location.sampleBarrier = Completer<LocationModel>();
      handler.onRepeatEvent(now.add(const Duration(minutes: 6)));
      await Future<void>.delayed(Duration.zero);
      handler.onRepeatEvent(now.add(const Duration(minutes: 12)));
      await Future<void>.delayed(Duration.zero);
      expect(location.samples, 2);
      location.sampleBarrier!.completeError(TimeoutException('GPS'));
      await Future<void>.delayed(Duration.zero);
      location.sampleBarrier = null;
      handler.onRepeatEvent(now.add(const Duration(minutes: 18)));
      await Future<void>.delayed(Duration.zero);
      expect(location.samples, 3);
      expect(backend.heartbeats, 4);
      expect(backend.publications, 1);
      expect(runtime.stops, 0);
      await handler.onDestroy(now, false);
      await location.positions.close();
    },
  );

  for (final status in [401, 403, 500]) {
    test('heartbeat status $status terminal vs temporary', () async {
      final location = _FakeLocationService();
      final backend = _FakeBackend()
        ..heartbeatError = ApiException(
          'No groups have effective location sharing enabled.',
          statusCode: status,
        );
      final runtime = _FakeRuntime();
      final handler = await _startHandler(
        location: location,
        backend: backend,
        runtime: runtime,
      );
      handler.onRepeatEvent(DateTime.now());
      await Future<void>.delayed(Duration.zero);
      expect(runtime.stops, status == 500 ? 0 : 1);
      await handler.onDestroy(DateTime.now(), false);
      await location.positions.close();
    });
  }

  for (final reason in [
    'session',
    'suspended',
    'permission',
    'sharing',
    'offline',
  ]) {
    test('startup validates $reason before GPS', () async {
      final location = _FakeLocationService();
      final backend = _FakeBackend();
      final runtime = _FakeRuntime();
      final session = _Session();
      if (reason == 'session') session.valid = false;
      if (reason == 'suspended') session.suspended = true;
      if (reason == 'permission') {
        location.permission = LocationPermissionStatus.whileInUse;
      }
      if (reason == 'sharing') backend.sharingEnabled = false;
      if (reason == 'offline') {
        backend.sharingError = TimeoutException('offline');
      }
      final handler = LocationTrackingTaskHandler(
        locationService: location,
        backendService: backend,
        runtime: runtime,
        sessionStorage: session,
        initializePlugins: false,
      );
      await handler.onStart(DateTime.now(), TaskStarter.system);
      expect(location.streams, 0);
      expect(location.samples, 0);
      expect(runtime.stops, reason == 'offline' ? 0 : 1);
      if (reason == 'offline') {
        backend.sharingError = null;
        handler.onRepeatEvent(DateTime.now());
        await Future<void>.delayed(Duration.zero);
        expect(location.streams, 1);
        expect(backend.publications, 1);
      }
      await handler.onDestroy(DateTime.now(), false);
      await location.positions.close();
    });
  }

  test('heartbeat is executed by the foreground task handler', () async {
    final location = _FakeLocationService();
    final backend = _FakeBackend();
    final runtime = _FakeRuntime();
    final handler = await _startHandler(
      location: location,
      backend: backend,
      runtime: runtime,
    );

    handler.onRepeatEvent(DateTime.now());
    await Future<void>.delayed(Duration.zero);

    expect(backend.heartbeats, 1);
    await handler.onDestroy(DateTime.now(), false);
    await location.positions.close();
  });

  test('temporary network errors do not stop tracking', () async {
    final location = _FakeLocationService();
    final backend = _FakeBackend()..publishError = Exception('offline');
    final runtime = _FakeRuntime();
    final handler = await _startHandler(
      location: location,
      backend: backend,
      runtime: runtime,
    );

    expect(runtime.stops, 0);
    expect(backend.publications, 1);
    await handler.onDestroy(DateTime.now(), false);
    await location.positions.close();
  });

  test('HTTP 401 stops stream and foreground service', () async {
    final location = _FakeLocationService();
    final backend = _FakeBackend()
      ..publishError = const ApiException('expired', statusCode: 401);
    final runtime = _FakeRuntime();
    final handler = await _startHandler(
      location: location,
      backend: backend,
      runtime: runtime,
    );

    expect(runtime.stops, 1);
    await handler.onDestroy(DateTime.now(), false);
    await location.positions.close();
  });
}
