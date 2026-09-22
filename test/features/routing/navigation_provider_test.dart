import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/services/location_service.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/routing/models/route_mode.dart';
import 'package:bond_front/features/routing/models/route_response.dart';
import 'package:bond_front/features/routing/providers/navigation_provider.dart';
import 'package:bond_front/features/routing/services/route_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _LocationService extends LocationService {
  LocationPermissionStatus permission = LocationPermissionStatus.whileInUse;
  Object? currentError;
  LocationModel current = _location(0, 0);
  int cancellations = 0;
  late final StreamController<LocationModel> positions =
      StreamController<LocationModel>.broadcast(
        sync: true,
        onCancel: () => cancellations++,
      );

  @override
  Future<LocationPermissionStatus> requestForegroundPermission() async =>
      permission;

  @override
  Future<LocationModel> getCurrentLocation() async {
    if (currentError != null) throw currentError!;
    return current;
  }

  @override
  Stream<LocationModel> getLocationStream() => positions.stream;
}

class _RouteService extends RouteService {
  _RouteService() : super(ApiClient(SessionStorageService()));

  final List<RouteResponse> responses = [];
  Object? nextError;
  int calls = 0;
  RouteMode? lastMode;
  LocationModel? lastOrigin;
  Completer<RouteResponse>? pending;

  @override
  Future<RouteResponse> calculate({
    required int groupId,
    required int pointId,
    required LocationModel origin,
    required RouteMode mode,
  }) async {
    calls++;
    lastMode = mode;
    lastOrigin = origin;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    final controlled = pending;
    if (controlled != null) return controlled.future;
    return responses.isEmpty ? _route() : responses.removeAt(0);
  }
}

LocationModel _location(
  double latitude,
  double longitude, {
  double accuracy = 5,
}) => LocationModel(
  latitude: latitude,
  longitude: longitude,
  accuracy: accuracy,
  timestamp: DateTime(2026),
);

RouteResponse _route({List<LatLng>? points}) => RouteResponse(
  points: points ?? const [LatLng(0, 0), LatLng(0, 0.01)],
  distanceMeters: 1112,
  durationSeconds: 300,
);

PointOfInterest _destination() => PointOfInterest(
  id: 5,
  name: 'Universidad',
  radius: 15,
  latitude: 0,
  longitude: 0.01,
  groupId: 3,
  createdAt: DateTime(2026),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('inicia, conserva el modo y cancelar detiene el stream local', () async {
    final location = _LocationService();
    final routes = _RouteService();
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    expect(
      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.walking,
      ),
      isTrue,
    );
    expect(provider.active, isTrue);
    expect(routes.calls, 1);
    expect(routes.lastMode, RouteMode.walking);
    expect(provider.remainingPoints, hasLength(2));

    await provider.cancel();
    expect(provider.active, isFalse);
    expect(provider.remainingPoints, isEmpty);
    expect(location.cancellations, 1);
  });

  test('informa permiso denegado y ubicación no disponible', () async {
    final location = _LocationService()
      ..permission = LocationPermissionStatus.denied;
    final routes = _RouteService();
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    expect(
      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.driving,
      ),
      isFalse,
    );
    expect(provider.errorMessage, contains('permiso'));
    expect(routes.calls, 0);
    expect(provider.targetPointId, isNull);

    location.permission = LocationPermissionStatus.whileInUse;
    location.currentError = Exception('Ubicación no disponible.');
    expect(
      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.driving,
      ),
      isFalse,
    );
    expect(provider.errorMessage, 'No se pudo obtener tu ubicación actual.');
    expect(provider.targetGroupId, isNull);
  });

  test(
    'cambio de grupo y limpieza de sesión finalizan la navegación',
    () async {
      final location = _LocationService();
      final routes = _RouteService();
      final provider = NavigationProvider(routes, location);
      addTearDown(provider.dispose);
      addTearDown(location.positions.close);

      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.driving,
      );
      await provider.handleActiveGroupChanged(3);
      expect(provider.active, isTrue);
      await provider.handleActiveGroupChanged(4);
      expect(provider.active, isFalse);

      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.walking,
      );
      await provider.clear();
      expect(provider.active, isFalse);
      expect(location.cancellations, 2);
    },
  );

  test('un cambio de grupo invalida un cálculo inicial pendiente', () async {
    final location = _LocationService();
    final completer = Completer<RouteResponse>();
    final routes = _RouteService()..pending = completer;
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    final starting = provider.start(
      point: _destination(),
      selectedMode: RouteMode.driving,
    );
    await _flush();
    expect(provider.targetGroupId, 3);
    await provider.handleActiveGroupChanged(4);
    completer.complete(_route());

    expect(await starting, isFalse);
    expect(provider.active, isFalse);
    expect(provider.remainingPoints, isEmpty);
  });

  test('avance normal oculta camino y no solicita otra ruta', () async {
    final location = _LocationService();
    final routes = _RouteService();
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);
    await provider.start(
      point: _destination(),
      selectedMode: RouteMode.walking,
    );

    location.positions.add(_location(0, 0.006));
    final advanced = provider.remainingDistanceMeters;
    location.positions.add(_location(0, 0.004));

    expect(provider.remainingDistanceMeters, advanced);
    expect(provider.remainingPoints.first.longitude, closeTo(0.006, 0.0001));
    expect(routes.calls, 1);
  });

  test('confirma desvío, recalcula una vez y respeta cooldown', () async {
    var now = DateTime(2026, 1, 1);
    final location = _LocationService();
    final routes = _RouteService()
      ..responses.addAll([
        _route(),
        _route(
          points: const [
            LatLng(0.001, 0.004),
            LatLng(0.0005, 0.008),
            LatLng(0, 0.01),
          ],
        ),
        _route(),
      ]);
    final provider = NavigationProvider(routes, location, clock: () => now);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);
    await provider.start(
      point: _destination(),
      selectedMode: RouteMode.driving,
    );

    location.positions.add(_location(0.001, 0.004));
    expect(routes.calls, 1);
    location.positions.add(_location(0.001, 0.0041));
    expect(routes.calls, 1);
    location.positions.add(_location(0.001, 0.0042));
    await _flush();
    expect(routes.calls, 2);
    expect(routes.lastOrigin?.longitude, 0.0042);

    for (var index = 0; index < 3; index++) {
      location.positions.add(_location(0.003, 0.004 + index * 0.0001));
    }
    await _flush();
    expect(routes.calls, 2);

    now = now.add(const Duration(seconds: 21));
    for (var index = 0; index < 3; index++) {
      location.positions.add(_location(0.003, 0.005 + index * 0.0001));
    }
    await _flush();
    expect(routes.calls, 3);
  });

  test(
    'fallo de recálculo conserva navegación y llegada la finaliza',
    () async {
      final location = _LocationService();
      final routes = _RouteService();
      final provider = NavigationProvider(routes, location);
      addTearDown(provider.dispose);
      addTearDown(location.positions.close);
      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.walking,
      );

      routes.nextError = Exception('proveedor caído');
      for (var index = 0; index < 3; index++) {
        location.positions.add(_location(0.001, 0.003 + index * 0.0001));
      }
      await _flush();
      expect(provider.active, isTrue);
      expect(provider.remainingPoints, isNotEmpty);
      expect(provider.errorMessage, contains('proveedor caído'));

      location.positions.add(_location(0, 0.00995));
      await _flush();
      expect(provider.active, isFalse);
      expect(provider.remainingPoints, isEmpty);
      expect(provider.takeNotice(), contains('Llegaste a Universidad'));
    },
  );
}
