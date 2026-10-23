import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/mandatory_group_location_action.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/location/services/location_backend_service.dart';
import 'package:bond_front/features/location/services/location_service.dart';
import 'package:bond_front/features/location/services/location_socket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends AppPreferencesService {
  @override
  Future<String?> getLocationPermissionStatus() async => null;

  @override
  Future<void> saveLocationPermissionStatus(String status) async {}
}

class _Backend extends LocationBackendService {
  _Backend(this.sharing) : super(ApiClient(SessionStorageService()));

  List<LocationSharingModel> sharing;

  @override
  Future<List<LocationSharingModel>> getSharing() async => sharing;

  @override
  Future<List<MemberLocationModel>> getGroupMembers(int groupId) async =>
      const [];
}

class _Location extends LocationService {
  LocationPermissionStatus permission = LocationPermissionStatus.unknown;
  LocationPermissionStatus foregroundResult =
      LocationPermissionStatus.whileInUse;
  LocationPermissionStatus backgroundResult = LocationPermissionStatus.always;
  int foregroundRequests = 0;
  int backgroundRequests = 0;
  int appSettingsOpens = 0;
  int locationSettingsOpens = 0;
  final positions = StreamController<LocationModel>.broadcast();

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestForegroundPermission() async {
    foregroundRequests++;
    permission = foregroundResult;
    return permission;
  }

  @override
  Future<LocationPermissionStatus> requestBackgroundPermission() async {
    backgroundRequests++;
    permission = backgroundResult;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpens++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpens++;
    return true;
  }

  @override
  Future<LocationModel> getCurrentLocation() async => LocationModel(
    latitude: -34.6,
    longitude: -58.4,
    accuracy: 5,
    timestamp: DateTime(2026),
  );

  @override
  Stream<LocationModel> getLocationStream() => positions.stream;
}

class _Background extends BackgroundLocationService {
  int starts = 0;
  int stops = 0;

  @override
  void addLocationListener(void Function(LocationModel) listener) {}

  @override
  void removeLocationListener(void Function(LocationModel) listener) {}

  @override
  Future<void> ensureRunning() async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _Socket extends LocationSocketService {
  _Socket() : super(SessionStorageService());

  final controller = StreamController<LocationSocketEvent>.broadcast();

  @override
  Stream<LocationSocketEvent> get events => controller.stream;

  @override
  Future<void> connect(int groupId) async {}

  @override
  Future<void> disconnect() async {}
}

const _optionalGroup = LocationSharingModel(
  memberId: 1,
  groupId: 10,
  locationSharingEnabled: false,
  shareLocationMandatorily: false,
  effectiveLocationSharing: false,
);

const _mandatoryGroup = LocationSharingModel(
  memberId: 2,
  groupId: 20,
  locationSharingEnabled: false,
  shareLocationMandatorily: true,
  effectiveLocationSharing: true,
);

ProviderContainer _createContainer({
  required _Backend backend,
  required _Location location,
  required _Background background,
  required _Socket socket,
}) {
  return ProviderContainer(
    overrides: [
      appPreferencesProvider.overrideWithValue(_Preferences()),
      locationBackendServiceProvider.overrideWithValue(backend),
      locationServiceProvider.overrideWithValue(location),
      backgroundLocationServiceProvider.overrideWithValue(background),
      locationSocketServiceProvider.overrideWithValue(socket),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'solicita permiso foreground y muestra ubicación en grupo opcional',
    () async {
      final location = _Location();
      final background = _Background();
      final socket = _Socket();
      final container = _createContainer(
        backend: _Backend([_optionalGroup]),
        location: location,
        background: background,
        socket: socket,
      );
      addTearDown(location.positions.close);
      addTearDown(container.dispose);
      addTearDown(socket.controller.close);

      await container
          .read(locationProvider.notifier)
          .restoreSharingAndTracking();

      final state = container.read(locationProvider);
      expect(location.foregroundRequests, 1);
      expect(location.backgroundRequests, 0);
      expect(state.currentLocation, isNotNull);
      expect(state.isTracking, isFalse);
      expect(state.sharing, contains(_optionalGroup));
      expect(background.starts, 0);

      final nextLocation = LocationModel(
        latitude: -34.61,
        longitude: -58.39,
        accuracy: 4,
        timestamp: DateTime(2026, 1, 2),
      );
      location.positions.add(nextLocation);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationProvider).currentLocation, nextLocation);
    },
  );

  test('solicita permiso al abrir un grupo opcional', () async {
    final location = _Location();
    final background = _Background();
    final socket = _Socket();
    final container = _createContainer(
      backend: _Backend([_optionalGroup]),
      location: location,
      background: background,
      socket: socket,
    );
    addTearDown(location.positions.close);
    addTearDown(container.dispose);
    addTearDown(socket.controller.close);

    await container.read(locationProvider.notifier).startViewingGroup(10);

    expect(location.foregroundRequests, 1);
    expect(container.read(locationProvider).currentLocation, isNotNull);
    expect(container.read(locationProvider).activeGroupId, 10);
  });

  test('mantiene en el grupo opcional al rechazarse el permiso', () async {
    final location = _Location()
      ..foregroundResult = LocationPermissionStatus.denied;
    final background = _Background();
    final socket = _Socket();
    final container = _createContainer(
      backend: _Backend([_optionalGroup]),
      location: location,
      background: background,
      socket: socket,
    );
    addTearDown(location.positions.close);
    addTearDown(container.dispose);
    addTearDown(socket.controller.close);
    final removedGroups = <int>[];
    container.read(locationProvider.notifier).setMandatoryGroupExitHandler((
      groupId,
    ) async {
      removedGroups.add(groupId);
      return true;
    });

    await container.read(locationProvider.notifier).restoreSharingAndTracking();

    final state = container.read(locationProvider);
    expect(state.sharing, contains(_optionalGroup));
    expect(state.currentLocation, isNull);
    expect(removedGroups, isEmpty);
  });

  test(
    'sale del grupo obligatorio solo si se confirma en el diálogo',
    () async {
      final location = _Location()
        ..backgroundResult = LocationPermissionStatus.denied;
      final background = _Background();
      final socket = _Socket();
      final container = _createContainer(
        backend: _Backend([_optionalGroup, _mandatoryGroup]),
        location: location,
        background: background,
        socket: socket,
      );
      addTearDown(location.positions.close);
      addTearDown(container.dispose);
      addTearDown(socket.controller.close);
      final removedGroups = <int>[];
      final notifier = container.read(locationProvider.notifier)
        ..setMandatoryGroupLocationPrompt((groupId) async {
          expect(groupId, 20);
          return MandatoryGroupLocationAction.leaveGroup;
        })
        ..setMandatoryGroupExitHandler((groupId) async {
          removedGroups.add(groupId);
          return true;
        });

      await notifier.restoreSharingAndTracking();

      final state = container.read(locationProvider);
      expect(removedGroups, [20]);
      expect(state.sharing, contains(_optionalGroup));
      expect(state.sharing, isNot(contains(_mandatoryGroup)));
      expect(state.currentLocation, isNull);
    },
  );

  test(
    'activa Ajustes sin abandonar el grupo si se elige esa opción',
    () async {
      final location = _Location()
        ..backgroundResult = LocationPermissionStatus.denied;
      final background = _Background();
      final socket = _Socket();
      final container = _createContainer(
        backend: _Backend([_mandatoryGroup]),
        location: location,
        background: background,
        socket: socket,
      );
      addTearDown(location.positions.close);
      addTearDown(container.dispose);
      addTearDown(socket.controller.close);
      var leaveAttempts = 0;
      final notifier = container.read(locationProvider.notifier)
        ..setMandatoryGroupLocationPrompt((_) async {
          return MandatoryGroupLocationAction.activateLocation;
        })
        ..setMandatoryGroupExitHandler((_) async {
          leaveAttempts++;
          return true;
        });

      await notifier.restoreSharingAndTracking();

      expect(location.appSettingsOpens, 1);
      expect(location.locationSettingsOpens, 0);
      expect(leaveAttempts, 0);
      expect(
        container.read(locationProvider).sharing,
        contains(_mandatoryGroup),
      );
    },
  );

  test(
    'abre ajustes de ubicación si el servicio del dispositivo está apagado',
    () async {
      final location = _Location()
        ..permission = LocationPermissionStatus.serviceDisabled
        ..backgroundResult = LocationPermissionStatus.serviceDisabled;
      final background = _Background();
      final socket = _Socket();
      final container = _createContainer(
        backend: _Backend([_mandatoryGroup]),
        location: location,
        background: background,
        socket: socket,
      );
      addTearDown(location.positions.close);
      addTearDown(container.dispose);
      addTearDown(socket.controller.close);
      final notifier = container.read(locationProvider.notifier)
        ..setMandatoryGroupLocationPrompt((_) async {
          return MandatoryGroupLocationAction.activateLocation;
        });

      await notifier.restoreSharingAndTracking();

      expect(location.locationSettingsOpens, 1);
      expect(location.appSettingsOpens, 0);
      expect(
        container.read(locationProvider).sharing,
        contains(_mandatoryGroup),
      );
    },
  );

  test(
    'sale de un grupo obligatorio si se revoca permiso desde ajustes',
    () async {
      final location = _Location();
      final background = _Background();
      final socket = _Socket();
      final container = _createContainer(
        backend: _Backend([_mandatoryGroup]),
        location: location,
        background: background,
        socket: socket,
      );
      addTearDown(location.positions.close);
      addTearDown(container.dispose);
      addTearDown(socket.controller.close);
      final removedGroups = <int>[];
      final notifier = container.read(locationProvider.notifier)
        ..setMandatoryGroupLocationPrompt((_) async {
          return MandatoryGroupLocationAction.leaveGroup;
        })
        ..setMandatoryGroupExitHandler((groupId) async {
          removedGroups.add(groupId);
          return true;
        });

      await notifier.restoreSharingAndTracking();
      expect(container.read(locationProvider).isTracking, isTrue);

      location.permission = LocationPermissionStatus.denied;
      await notifier.refreshAfterAppResume();

      expect(removedGroups, [20]);
      expect(container.read(locationProvider).sharing, isEmpty);
      expect(container.read(locationProvider).isTracking, isFalse);
    },
  );
}
