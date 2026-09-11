import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/services/location_backend_service.dart';
import 'package:bond_front/features/location/services/location_service.dart';
import 'package:bond_front/features/location/services/location_tracking_task_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService extends LocationService {
  final positions = StreamController<LocationModel>();
  final current = LocationModel(
    latitude: -34.6,
    longitude: -58.4,
    accuracy: 4,
    timestamp: DateTime.utc(2026, 9, 4),
  );

  @override
  Future<LocationModel> getCurrentLocation() async => current;

  @override
  Stream<LocationModel> getLocationStream() => positions.stream;

  @override
  double distanceBetween(LocationModel first, LocationModel second) => 100;
}

class _FakeBackend extends LocationBackendService {
  _FakeBackend() : super(ApiClient(SessionStorageService()));

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
  );
  await handler.onStart(DateTime.now(), TaskStarter.developer);
  return handler;
}

void main() {
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
