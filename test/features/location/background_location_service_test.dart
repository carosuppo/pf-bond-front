import 'dart:async';

import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements ForegroundTaskGateway {
  bool running = false;
  int starts = 0;
  int stops = 0;
  void Function(Object)? callback;
  final Completer<void>? startBarrier;

  _FakeGateway({this.startBarrier});

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<void> start() async {
    starts++;
    await startBarrier?.future;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  void addDataCallback(void Function(Object) callback) {
    this.callback = callback;
  }

  @override
  void removeDataCallback(void Function(Object) callback) {
    if (this.callback == callback) this.callback = null;
  }
}

void main() {
  test('multiple concurrent starts create one service', () async {
    final barrier = Completer<void>();
    final gateway = _FakeGateway(startBarrier: barrier);
    final service = BackgroundLocationService(gateway: gateway);

    final first = service.ensureRunning();
    final second = service.ensureRunning();
    barrier.complete();
    await Future.wait([first, second]);

    expect(gateway.starts, 1);
  });

  test('start reuses an already running service', () async {
    final gateway = _FakeGateway()..running = true;
    final service = BackgroundLocationService(gateway: gateway);

    await service.ensureRunning();

    expect(gateway.starts, 0);
  });

  test('stop is idempotent when service is not running', () async {
    final gateway = _FakeGateway();
    final service = BackgroundLocationService(gateway: gateway);

    await service.stop();

    expect(gateway.stops, 0);
  });

  test(
    'stop requested during startup does not leave a service running',
    () async {
      final barrier = Completer<void>();
      final gateway = _FakeGateway(startBarrier: barrier);
      final service = BackgroundLocationService(gateway: gateway);

      final starting = service.ensureRunning();
      final stopping = service.stop();
      barrier.complete();
      await Future.wait([starting, stopping]);

      expect(gateway.starts, 1);
      expect(gateway.stops, 1);
      expect(gateway.running, isFalse);
    },
  );

  test('foreground location event is delivered to the UI listener', () {
    final gateway = _FakeGateway();
    final service = BackgroundLocationService(gateway: gateway);
    LocationModel? received;
    void listener(LocationModel value) => received = value;
    service.addLocationListener(listener);

    gateway.callback?.call(<String, Object>{
      'type': 'location',
      'latitude': -34.6,
      'longitude': -58.4,
      'accuracy': 5.0,
      'timestamp': '2026-09-04T12:00:00.000Z',
    });

    expect(received?.latitude, -34.6);
    expect(received?.longitude, -58.4);
    service.removeLocationListener(listener);
    expect(gateway.callback, isNull);
  });
}
