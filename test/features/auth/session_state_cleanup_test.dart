import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/routes/app_routes.dart';
import 'package:bond_front/core/routes/navigation/post_auth_navigator.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/models/auth_response.dart';
import 'package:bond_front/features/auth/models/user_model.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/event/models/event_model.response.dart';
import 'package:bond_front/features/event/providers/event_provider.dart';
import 'package:bond_front/features/event/services/event_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/point_of_interest/providers/point_of_interest_provider.dart';
import 'package:bond_front/features/point_of_interest/services/point_of_interest_service.dart';
import 'package:bond_front/features/profile/providers/profile_provider.dart';
import 'package:bond_front/features/profile/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends SessionStorageService {
  bool hasToken = true;
  bool failClear = false;
  int clearCalls = 0;

  @override
  Future<bool> hasValidSession() async => hasToken;

  @override
  Future<String?> getSessionToken() async => hasToken ? 'token-viejo' : null;

  @override
  Future<DateTime?> getSessionExpiration() async => DateTime(2027);

  @override
  Future<void> saveSession({
    required String sessionToken,
    required DateTime expiresAt,
  }) async {
    hasToken = true;
  }

  @override
  Future<void> clearSession() async {
    clearCalls++;
    if (failClear) throw Exception('secure storage');
    hasToken = false;
  }
}

class _Preferences extends AppPreferencesService {
  int? activeGroupId;
  bool failClear = false;
  int clearCalls = 0;
  Completer<void>? saveBlocker;

  @override
  Future<void> saveActiveGroupId(int groupId) async {
    await saveBlocker?.future;
    activeGroupId = groupId;
  }

  @override
  Future<int?> getActiveGroupId() async => activeGroupId;

  @override
  Future<void> clearActiveGroupId() async {
    clearCalls++;
    if (failClear) throw Exception('preferences');
    activeGroupId = null;
  }
}

class _Api extends ApiClient {
  _Api(super.sessionStorage);
  bool failDelete = false;
  int deleteCalls = 0;
  int logoutCalls = 0;
  int loginUserId = 1;

  @override
  Future<Map<String, dynamic>> authenticatedGet(String path) async =>
      throw Exception('401');

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {
    'sessionToken': 'token-$loginUserId',
    'expiresAt': DateTime(2027).toIso8601String(),
    'user': {
      'id': loginUserId,
      'name': 'Usuario $loginUserId',
      'email': 'usuario$loginUserId@bond.test',
      'locationId': null,
      'createdAt': DateTime(2026).toIso8601String(),
      'updatedAt': DateTime(2026).toIso8601String(),
    },
  };

  @override
  Future<void> authenticatedDelete(String path) async {
    deleteCalls++;
    if (failDelete) throw Exception('DELETE falló');
  }

  @override
  Future<void> authenticatedPostNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    logoutCalls++;
  }
}

class _Push extends PushNotificationService {
  _Push(_Api api, _Preferences preferences)
    : super(NotificationApiService(api), preferences);

  bool authenticated = true;
  int localClearCalls = 0;
  int unregisterCalls = 0;

  @override
  Future<void> onAuthenticated() async {
    authenticated = true;
  }

  @override
  Future<void> unregisterCurrentDevice() async {
    unregisterCalls++;
  }

  @override
  void onLoggedOut() {
    authenticated = false;
    localClearCalls++;
  }
}

class _Background extends BackgroundLocationService {
  bool failStop = false;
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    if (failStop) throw Exception('tracking');
  }
}

class _Groups extends GroupService {
  _Groups() : super(ApiClient(SessionStorageService()));
  List<GetGroupsResponseModel> current = [
    GetGroupsResponseModel(id: 10, name: 'Grupo A'),
  ];
  int loads = 0;
  Completer<List<GetGroupsResponseModel>>? nextLoad;

  @override
  Future<List<GetGroupsResponseModel>> getGroups() async {
    loads++;
    final pending = nextLoad;
    if (pending != null) {
      nextLoad = null;
      return pending.future;
    }
    return current;
  }

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async =>
      GetGroupResponseModel(
        id: groupId,
        name: current.first.name,
        shareLocationMandatorily: false,
        invitationCode: 'ABC123',
        members: [],
      );
}

class _Location extends LocationProvider {
  @override
  LocationState build() => LocationState.initial();

  @override
  Future<void> resetSessionState() async => state = LocationState.initial();

  void seed() {
    state = LocationState(
      isLoading: false,
      isTracking: true,
      permissionStatus: LocationState.initial().permissionStatus,
      sharing: const [
        LocationSharingModel(
          memberId: 1,
          groupId: 10,
          locationSharingEnabled: true,
          shareLocationMandatorily: false,
          effectiveLocationSharing: true,
        ),
      ],
      visibleMembers: {
        2: const MemberLocationModel(
          memberId: 2,
          userId: 2,
          name: 'Otro',
          latitude: 1,
          longitude: 2,
        ),
      },
      activeGroupId: 10,
      currentLocation: LocationModel(
        latitude: 1,
        longitude: 2,
        accuracy: 3,
        timestamp: DateTime(2026),
      ),
      errorMessage: 'error anterior',
    );
  }
}

class _Fixture {
  _Fixture() {
    api = _Api(storage);
    push = _Push(api, preferences);
    groupsService = _Groups();
    group = GroupProvider(groupsService, preferences);
    profile = ProfileProvider(ProfileService(api), groupsService);
    points = PointOfInterestProvider(PointOfInterestService(api));
    events = EventProvider(EventService(api));
    container = ProviderContainer(
      overrides: [locationProvider.overrideWith(_Location.new)],
    );
    cleanup = LocalSessionStateCleanup(
      storage: storage,
      push: push,
      preferences: preferences,
      group: group,
      profile: profile,
      points: points,
      events: events,
      locationContainer: container,
      backgroundLocation: background,
    );
    auth = AuthProvider(AuthService(api, storage, push, background), cleanup);
    auth.authResponse = AuthResponse(
      sessionToken: 'A',
      expiresAt: DateTime(2027),
      user: _user(1),
    );
  }

  final _Storage storage = _Storage();
  final _Preferences preferences = _Preferences();
  final _Background background = _Background();
  late final _Api api;
  late final _Push push;
  late final _Groups groupsService;
  late final GroupProvider group;
  late final ProfileProvider profile;
  late final PointOfInterestProvider points;
  late final EventProvider events;
  late final ProviderContainer container;
  late final LocalSessionStateCleanup cleanup;
  late final AuthProvider auth;

  Future<void> seedA() async {
    await group.initialize();
    profile.user = _user(1);
    profile.groups = [...group.groups];
    points.points = [
      PointOfInterest(
        id: 3,
        name: 'POI de A',
        radius: 10,
        latitude: 1,
        longitude: 2,
        groupId: 10,
        createdAt: DateTime(2026),
      ),
    ];
    events.events = [
      EventResponseModel(
        id: 4,
        name: 'Evento de A',
        startAt: DateTime(2026),
        memberIds: const [],
      ),
    ];
    (container.read(locationProvider.notifier) as _Location).seed();
  }

  void dispose() {
    auth.dispose();
    group.dispose();
    profile.dispose();
    points.dispose();
    events.dispose();
    container.dispose();
  }
}

UserModel _user(int id) => UserModel(
  id: id,
  name: 'Usuario $id',
  email: 'usuario$id@bond.test',
  locationId: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void _expectCleared(_Fixture fixture) {
  expect(fixture.auth.authResponse, isNull);
  expect(fixture.group.isInitialized, isFalse);
  expect(fixture.group.groups, isEmpty);
  expect(fixture.group.activeGroup, isNull);
  expect(fixture.group.groupDetails, isNull);
  expect(fixture.group.group, isNull);
  expect(fixture.group.updatedGroup, isNull);
  expect(fixture.group.joinResponse, isNull);
  expect(fixture.group.errorMessage, isNull);
  expect(fixture.profile.user, isNull);
  expect(fixture.profile.groups, isEmpty);
  expect(fixture.points.points, isEmpty);
  expect(fixture.events.events, isEmpty);
  final location = fixture.container.read(locationProvider);
  expect(location.visibleMembers, isEmpty);
  expect(location.currentLocation, isNull);
  expect(location.sharing, isEmpty);
  expect(location.activeGroupId, isNull);
  expect(location.isTracking, isFalse);
  expect(location.errorMessage, isNull);
  expect(fixture.push.authenticated, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'delete limpia todos los providers y B vuelve a cargar sus grupos',
    () async {
      final fixture = _Fixture();
      expect(await fixture.auth.login(email: 'A', password: 'clave'), isTrue);
      await fixture.seedA();
      expect(fixture.group.isInitialized, isTrue);
      expect(fixture.preferences.activeGroupId, 10);

      expect(await fixture.auth.deleteAccount(), isTrue);
      _expectCleared(fixture);
      expect(fixture.storage.hasToken, isFalse);
      expect(fixture.preferences.activeGroupId, isNull);
      expect(fixture.background.stopCalls, 1);
      expect(fixture.api.logoutCalls, 0);
      expect(fixture.push.unregisterCalls, 0);

      fixture.groupsService.current = [
        GetGroupsResponseModel(id: 20, name: 'Grupo B'),
      ];
      fixture.api.loginUserId = 2;
      expect(await fixture.auth.login(email: 'B', password: 'clave'), isTrue);
      await fixture.group.initialize();
      expect(fixture.auth.authResponse?.user.id, 2);
      expect(fixture.groupsService.loads, 2);
      expect(fixture.group.groups.single.id, 20);
      expect(fixture.group.activeGroup?.id, 20);
      expect(fixture.group.groupDetails?.id, 20);
      expect(fixture.preferences.activeGroupId, 20);
      fixture.dispose();
    },
  );

  testWidgets('A con grupo, B sin grupo navega a crear o unirse', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.seedA();
    expect(await fixture.auth.deleteAccount(), isTrue);
    fixture.groupsService.current = [];
    fixture.api.loginUserId = 2;
    expect(await fixture.auth.login(email: 'B', password: 'clave'), isTrue);

    late BuildContext routeContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            routeContext = context;
            return const Scaffold(body: Text('Login B'));
          },
        ),
        routes: {
          AppRoutes.groups: (_) => const Scaffold(body: Text('Crear o unirse')),
          AppRoutes.map: (_) => const Scaffold(body: Text('Mapa')),
        },
      ),
    );
    await const PostAuthNavigator().navigate(
      context: routeContext,
      groupProvider: fixture.group,
      locationNotifier: fixture.container.read(locationProvider.notifier),
    );
    await tester.pumpAndSettle();
    expect(fixture.groupsService.loads, 2);
    expect(fixture.group.groups, isEmpty);
    expect(fixture.group.activeGroup, isNull);
    expect(fixture.preferences.activeGroupId, isNull);
    expect(find.text('Crear o unirse'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
    fixture.dispose();
  });

  test(
    'logout usa el mismo reset tras detener servicios y llamar backend',
    () async {
      final fixture = _Fixture();
      await fixture.seedA();
      expect(await fixture.auth.logout(), isTrue);
      _expectCleared(fixture);
      expect(fixture.api.logoutCalls, 1);
      expect(fixture.push.unregisterCalls, 1);
      expect(fixture.background.stopCalls, 2);
      expect(fixture.preferences.activeGroupId, isNull);
      fixture.groupsService.current = [];
      fixture.api.loginUserId = 2;
      expect(await fixture.auth.login(email: 'B', password: 'clave'), isTrue);
      await fixture.group.initialize();
      expect(fixture.auth.authResponse?.user.id, 2);
      expect(fixture.groupsService.loads, 2);
      expect(fixture.group.groups, isEmpty);
      expect(fixture.group.activeGroup, isNull);
      fixture.dispose();
    },
  );

  test('DELETE fallido conserva toda la sesión', () async {
    final fixture = _Fixture();
    await fixture.seedA();
    fixture.api.failDelete = true;
    expect(await fixture.auth.deleteAccount(), isFalse);
    expect(fixture.auth.authResponse, isNotNull);
    expect(fixture.group.isInitialized, isTrue);
    expect(fixture.group.activeGroup?.id, 10);
    expect(fixture.profile.user?.id, 1);
    expect(fixture.container.read(locationProvider).isTracking, isTrue);
    expect(fixture.storage.clearCalls, 0);
    expect(fixture.preferences.clearCalls, 0);
    fixture.dispose();
  });

  test('logout completa el cierre aunque detener tracking falle', () async {
    final fixture = _Fixture();
    await fixture.seedA();
    fixture.background.failStop = true;
    expect(await fixture.auth.logout(), isTrue);
    _expectCleared(fixture);
    expect(fixture.api.logoutCalls, 1);
    expect(fixture.push.unregisterCalls, 1);
    expect(fixture.background.stopCalls, 2);
    fixture.dispose();
  });

  for (final failedStep in ['storage', 'preferences', 'tracking']) {
    test('DELETE 204 mantiene éxito si falla $failedStep', () async {
      final fixture = _Fixture();
      await fixture.seedA();
      fixture.storage.failClear = failedStep == 'storage';
      fixture.preferences.failClear = failedStep == 'preferences';
      fixture.background.failStop = failedStep == 'tracking';

      expect(await fixture.auth.deleteAccount(), isTrue);
      _expectCleared(fixture);
      expect(fixture.auth.errorMessage, isNull);
      expect(fixture.storage.clearCalls, 1);
      expect(fixture.preferences.clearCalls, greaterThanOrEqualTo(1));
      expect(fixture.background.stopCalls, 1);
      expect(fixture.push.localClearCalls, 1);
      fixture.dispose();
    });
  }

  test(
    'restore rechaza y vuelve a borrar un token viejo tras DELETE',
    () async {
      final fixture = _Fixture();
      fixture.storage.failClear = true;
      expect(await fixture.auth.deleteAccount(), isTrue);
      expect(fixture.storage.hasToken, isTrue);
      fixture.storage.failClear = false;
      expect(await fixture.auth.restoreSession(), isFalse);
      expect(fixture.auth.authResponse, isNull);
      expect(fixture.storage.hasToken, isFalse);
      expect(fixture.storage.clearCalls, 2);
      fixture.dispose();
    },
  );

  test('espera una preferencia pendiente antes de limpiar la sesión', () async {
    final fixture = _Fixture();
    await fixture.seedA();
    final blocker = Completer<void>();
    fixture.preferences.saveBlocker = blocker;
    final selection = fixture.group.selectGroup(fixture.group.groups.single);
    final deletion = fixture.auth.deleteAccount();
    blocker.complete();
    await selection;
    expect(await deletion, isTrue);
    expect(fixture.preferences.activeGroupId, isNull);
    expect(fixture.group.activeGroup, isNull);
    fixture.dispose();
  });

  test(
    'una carga pendiente de A no repuebla GroupProvider tras DELETE',
    () async {
      final fixture = _Fixture();
      await fixture.seedA();
      final pending = Completer<List<GetGroupsResponseModel>>();
      fixture.groupsService.nextLoad = pending;
      final oldLoad = fixture.group.loadGroups();
      expect(await fixture.auth.deleteAccount(), isTrue);
      pending.complete([GetGroupsResponseModel(id: 10, name: 'Grupo A')]);
      await oldLoad;
      expect(fixture.group.groups, isEmpty);
      expect(fixture.group.isInitialized, isFalse);
      fixture.dispose();
    },
  );
}
