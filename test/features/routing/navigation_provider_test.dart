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
  int currentCalls = 0;
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
    currentCalls++;
    if (currentError != null) throw currentError!;
    return current;
  }

  @override
  Stream<LocationModel> getLocationStream() => positions.stream;
}

class _RouteService extends RouteService {
  _RouteService() : super(ApiClient(SessionStorageService()));

  final List<RouteResponse> responses = [];
  final List<Completer<RouteResponse>> pendingResponses = [];
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
    if (pendingResponses.isNotEmpty) {
      return pendingResponses.removeAt(0).future;
    }
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

RouteResponse _route({
  List<LatLng>? points,
  double distanceMeters = 1112,
  double durationSeconds = 300,
}) => RouteResponse(
  points: points ?? const [LatLng(0, 0), LatLng(0, 0.01)],
  distanceMeters: distanceMeters,
  durationSeconds: durationSeconds,
);

PointOfInterest _destination({
  int id = 5,
  int groupId = 3,
  String name = 'Universidad',
  double radius = 15,
  double latitude = 0,
  double longitude = 0.01,
}) => PointOfInterest(
  id: id,
  name: name,
  radius: radius,
  latitude: latitude,
  longitude: longitude,
  groupId: groupId,
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
    expect(provider.routeRevision, 1);

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

  test('conserva metadata actualizada durante el cálculo inicial', () async {
    final location = _LocationService();
    final initialRequest = Completer<RouteResponse>();
    final routes = _RouteService()..pendingResponses.add(initialRequest);
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    final starting = provider.start(
      point: _destination(radius: 25),
      selectedMode: RouteMode.walking,
    );
    await _flush();
    expect(routes.calls, 1);

    await provider.handleDestinationUpdated(
      _destination(name: 'UTN', radius: 150),
    );
    initialRequest.complete(_route());

    expect(await starting, isTrue);
    expect(provider.destination?.name, 'UTN');
    expect(provider.destination?.radius, 150);
    expect(routes.calls, 1);
  });

  test('una ruta inicial vieja no gana si cambian las coordenadas', () async {
    final location = _LocationService();
    final requestA = Completer<RouteResponse>();
    final requestB = Completer<RouteResponse>();
    final routes = _RouteService()
      ..pendingResponses.addAll([requestA, requestB]);
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    final starting = provider.start(
      point: _destination(),
      selectedMode: RouteMode.driving,
    );
    await _flush();
    expect(routes.calls, 1);

    final destinationUpdate = provider.handleDestinationUpdated(
      _destination(latitude: 0.005, longitude: 0.02),
    );
    await _flush();
    expect(routes.calls, 2);

    requestB.complete(
      _route(
        points: const [LatLng(0, 0), LatLng(0.005, 0.02)],
        durationSeconds: 222,
      ),
    );
    await destinationUpdate;
    expect(await starting, isTrue);
    final revisionForB = provider.routeRevision;

    requestA.complete(
      _route(
        points: const [LatLng(0, 0), LatLng(0, 0.01)],
        durationSeconds: 111,
      ),
    );
    await _flush();

    expect(provider.destination?.latitude, 0.005);
    expect(provider.destination?.longitude, 0.02);
    expect(provider.remainingPoints.last, const LatLng(0.005, 0.02));
    expect(provider.durationSeconds, 222);
    expect(provider.routeRevision, revisionForB);
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

    location.positions.add(_location(0, 0.004));
    location.positions.add(_location(0, 0.006));
    final advanced = provider.remainingDistanceMeters;
    location.positions.add(_location(0, 0.004));

    expect(provider.remainingDistanceMeters, advanced);
    expect(provider.remainingPoints.first.longitude, closeTo(0.006, 0.0001));
    expect(routes.calls, 1);
    expect(provider.routeRevision, 1);
  });

  test('sincroniza datos visuales sin solicitar otra ruta', () async {
    final location = _LocationService();
    final routes = _RouteService();
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);
    await provider.start(
      point: _destination(),
      selectedMode: RouteMode.walking,
    );

    await provider.handleDestinationUpdated(_destination(name: 'UTN'));
    await provider.handleDestinationUpdated(
      _destination(id: 8, name: 'Otro punto'),
    );
    await provider.handleDestinationUpdated(
      _destination(groupId: 4, name: 'Otro grupo'),
    );

    expect(provider.destination?.name, 'UTN');
    expect(routes.calls, 1);
    expect(provider.routeRevision, 1);
  });

  test(
    'usa el radio actualizado para detectar llegada sin recalcular',
    () async {
      final location = _LocationService();
      final routes = _RouteService();
      final provider = NavigationProvider(routes, location);
      addTearDown(provider.dispose);
      addTearDown(location.positions.close);
      await provider.start(
        point: _destination(radius: 15),
        selectedMode: RouteMode.walking,
      );

      await provider.handleDestinationUpdated(_destination(radius: 150));
      location.positions.add(_location(0, 0.009));
      await _flush();

      expect(provider.active, isFalse);
      expect(provider.remainingPoints, isEmpty);
      expect(provider.takeNotice(), 'Llegaste a Universidad.');
      expect(routes.calls, 1);
    },
  );

  test(
    'cambiar coordenadas recalcula desde la ubicación más reciente',
    () async {
      final location = _LocationService();
      final routes = _RouteService()
        ..responses.addAll([
          _route(),
          _route(
            points: const [LatLng(0, 0.004), LatLng(0.005, 0.02)],
            durationSeconds: 420,
          ),
        ]);
      final provider = NavigationProvider(routes, location);
      addTearDown(provider.dispose);
      addTearDown(location.positions.close);
      await provider.start(
        point: _destination(),
        selectedMode: RouteMode.driving,
      );
      location.positions.add(_location(0, 0.004));

      await provider.handleDestinationUpdated(
        _destination(latitude: 0.005, longitude: 0.02),
      );

      expect(provider.destination?.latitude, 0.005);
      expect(provider.destination?.longitude, 0.02);
      expect(routes.calls, 2);
      expect(routes.lastMode, RouteMode.driving);
      expect(routes.lastOrigin?.longitude, 0.004);
      expect(provider.remainingPoints.last, const LatLng(0.005, 0.02));
      expect(provider.durationSeconds, 420);
      expect(provider.routeRevision, 2);
      expect(provider.recalculating, isFalse);
    },
  );

  test('una respuesta anterior no pisa la ruta al nuevo destino', () async {
    final location = _LocationService();
    final routes = _RouteService();
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);
    await provider.start(
      point: _destination(),
      selectedMode: RouteMode.driving,
    );
    final requestA = Completer<RouteResponse>();
    final requestB = Completer<RouteResponse>();
    routes.pendingResponses.addAll([requestA, requestB]);

    for (var index = 0; index < 3; index++) {
      location.positions.add(_location(0.002, 0.003 + index * 0.0001));
    }
    await _flush();
    expect(routes.calls, 2);

    final destinationUpdate = provider.handleDestinationUpdated(
      _destination(latitude: 0.005, longitude: 0.02),
    );
    await _flush();
    expect(routes.calls, 3);

    requestB.complete(
      _route(
        points: const [LatLng(0.002, 0.0032), LatLng(0.005, 0.02)],
        distanceMeters: 2200,
        durationSeconds: 222,
      ),
    );
    await destinationUpdate;
    final revisionForB = provider.routeRevision;
    expect(provider.remainingPoints.last, const LatLng(0.005, 0.02));
    expect(provider.durationSeconds, 222);

    requestA.complete(
      _route(
        points: const [LatLng(0.002, 0.0032), LatLng(0, 0.01)],
        durationSeconds: 111,
      ),
    );
    await _flush();

    expect(provider.destination?.longitude, 0.02);
    expect(provider.remainingPoints.last, const LatLng(0.005, 0.02));
    expect(provider.durationSeconds, 222);
    expect(provider.routeRevision, revisionForB);
    expect(provider.recalculating, isFalse);
  });

  test('destino no disponible invalida un cálculo pendiente y avisa', () async {
    final location = _LocationService();
    final pendingRoute = Completer<RouteResponse>();
    final routes = _RouteService()..pending = pendingRoute;
    final provider = NavigationProvider(routes, location);
    addTearDown(provider.dispose);
    addTearDown(location.positions.close);

    final starting = provider.start(
      point: _destination(),
      selectedMode: RouteMode.walking,
    );
    await _flush();
    await provider.handleDestinationUnavailable();
    pendingRoute.complete(_route());

    expect(await starting, isFalse);
    expect(provider.active, isFalse);
    expect(provider.remainingPoints, isEmpty);
    expect(provider.takeNotice(), 'El destino ya no está disponible.');
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
    expect(provider.routeRevision, 2);

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
    expect(provider.routeRevision, 3);
  });

  test(
    'un recálculo cancelado no publica una nueva revisión de ruta',
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
      final initialRevision = provider.routeRevision;
      final pendingRecalculation = Completer<RouteResponse>();
      routes.pending = pendingRecalculation;

      for (var index = 0; index < 3; index++) {
        location.positions.add(_location(0.002, 0.003 + index * 0.0001));
      }
      await _flush();
      expect(provider.recalculating, isTrue);

      await provider.cancel();
      pendingRecalculation.complete(_route());
      await _flush();

      expect(provider.active, isFalse);
      expect(provider.routeRevision, initialRevision);
      expect(provider.remainingPoints, isEmpty);
    },
  );

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
