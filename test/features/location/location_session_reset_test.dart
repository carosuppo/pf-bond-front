import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
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
  Future<String?> getLocationPermissionStatus() async => 'always';

  @override
  Future<void> saveLocationPermissionStatus(String status) async {}
}

class _Backend extends LocationBackendService {
  _Backend() : super(ApiClient(SessionStorageService()));

  @override
  Future<List<LocationSharingModel>> getSharing() async => const [
    LocationSharingModel(
      memberId: 1,
      groupId: 10,
      locationSharingEnabled: true,
      shareLocationMandatorily: false,
      effectiveLocationSharing: true,
    ),
  ];

  @override
  Future<List<MemberLocationModel>> getGroupMembers(int groupId) async =>
      const [
        MemberLocationModel(
          memberId: 2,
          userId: 2,
          name: 'Otro',
          latitude: 1,
          longitude: 2,
        ),
      ];
}

class _LocationService extends LocationService {
  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.always;

  @override
  Future<LocationModel> getCurrentLocation() async => LocationModel(
    latitude: 1,
    longitude: 2,
    accuracy: 3,
    timestamp: DateTime(2026),
  );
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
  bool connected = false;
  int disconnects = 0;

  @override
  Stream<LocationSocketEvent> get events => controller.stream;

  @override
  Future<void> connect(int groupId) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    disconnects++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reset de Riverpod limpia ubicación y cierra socket y tracking',
    () async {
      final background = _Background();
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(_Preferences()),
          locationBackendServiceProvider.overrideWithValue(_Backend()),
          locationServiceProvider.overrideWithValue(_LocationService()),
          backgroundLocationServiceProvider.overrideWithValue(background),
          locationSocketServiceProvider.overrideWithValue(socket),
        ],
      );
      final notifier = container.read(locationProvider.notifier);
      await notifier.restoreSharingAndTracking();
      await notifier.startViewingGroup(10);
      final before = container.read(locationProvider);
      expect(before.isTracking, isTrue);
      expect(before.currentLocation, isNotNull);
      expect(before.sharing, isNotEmpty);
      expect(before.visibleMembers, isNotEmpty);
      expect(before.activeGroupId, 10);
      expect(socket.connected, isTrue);
      expect(socket.controller.hasListener, isTrue);

      await notifier.resetSessionState();
      final after = container.read(locationProvider);
      expect(after.isTracking, isFalse);
      expect(after.currentLocation, isNull);
      expect(after.sharing, isEmpty);
      expect(after.visibleMembers, isEmpty);
      expect(after.activeGroupId, isNull);
      expect(after.errorMessage, isNull);
      expect(socket.connected, isFalse);
      expect(socket.disconnects, 1);
      expect(socket.controller.hasListener, isFalse);
      expect(background.stops, 1);
      container.dispose();
      await socket.controller.close();
    },
  );
}
