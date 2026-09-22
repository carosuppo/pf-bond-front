import 'dart:async';
import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/location/constants/default_location.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/screens/map_screen.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/location/services/location_socket_service.dart';
import 'package:bond_front/features/location/services/location_service.dart';
import 'package:bond_front/features/location/widgets/location_map.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:bond_front/features/point_of_interest/providers/point_of_interest_provider.dart';
import 'package:bond_front/features/point_of_interest/services/point_of_interest_service.dart';
import 'package:bond_front/features/routing/models/route_mode.dart';
import 'package:bond_front/features/routing/providers/navigation_provider.dart';
import 'package:bond_front/features/routing/services/route_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart' as provider;

class _NoopSessionStateCleanup implements SessionStateCleanup {
  @override
  Future<void> clear() async {}
}

class MemoryApi extends ApiClient {
  MemoryApi() : super(SessionStorageService());
  Map<String, dynamic> point = {
    'id': 1,
    'name': 'Colegio',
    'description': 'Punto de encuentro',
    'radius': 100,
    'latitude': defaultLocation.latitude,
    'longitude': defaultLocation.longitude,
    'groupId': 20,
    'createdAt': '2026-08-01T00:00:00Z',
    'color': 'RED',
  };
  final List<Map<String, dynamic>> additionalPoints = [];
  bool deleted = false;
  int routeCalls = 0;
  @override
  Future<List<Map<String, dynamic>>> authenticatedGetList(String path) async =>
      [Map.of(point), ...additionalPoints.map(Map<String, dynamic>.of)];
  @override
  Future<Map<String, dynamic>> authenticatedPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    point = {...point, ...body};
    return Map.of(point);
  }

  @override
  Future<Map<String, dynamic>> authenticatedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    routeCalls++;
    return {
      'points': [
        {
          'latitude': body['originLatitude'],
          'longitude': body['originLongitude'],
        },
        {'latitude': point['latitude'], 'longitude': point['longitude']},
      ],
      'distanceMeters': 1200,
      'durationSeconds': 600,
    };
  }

  @override
  Future<void> authenticatedDelete(String path) async {
    deleted = true;
  }
}

class TestNavigationLocationService extends LocationService {
  int cancellations = 0;
  late final positions = StreamController<LocationModel>.broadcast(
    sync: true,
    onCancel: () => cancellations++,
  );

  @override
  Future<LocationPermissionStatus> requestForegroundPermission() async =>
      LocationPermissionStatus.whileInUse;

  @override
  Future<LocationModel> getCurrentLocation() async => LocationModel(
    latitude: defaultLocation.latitude,
    longitude: defaultLocation.longitude - 0.01,
    accuracy: 5,
    timestamp: DateTime(2026),
  );

  @override
  Stream<LocationModel> getLocationStream() => positions.stream;

  Future<void> close() => positions.close();
}

class StaticLocation extends LocationProvider {
  @override
  LocationState build() => LocationState.initial().copyWith(
    visibleMembers: {
      2: MemberLocationModel(
        memberId: 2,
        userId: 2,
        name: 'Ana',
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude + 1,
        lastSeenAt: DateTime.now(),
      ),
    },
  );
  @override
  Future<void> startViewingGroup(int groupId) async {}
  @override
  Future<void> stopViewingGroup() async {}
}

class TestSocket extends LocationSocketService {
  TestSocket() : super(SessionStorageService());
  final messages = StreamController<LocationSocketEvent>.broadcast();
  @override
  Stream<LocationSocketEvent> get events => messages.stream;
  @override
  Future<void> dispose() async {
    await messages.close();
    await super.dispose();
  }
}

void main() {
  testWidgets(
    'MapScreen aplica el modo navegación y cancela destinos ausentes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = MemoryApi();
      api.additionalPoints.add({
        'id': 2,
        'name': 'Parque',
        'description': 'Segundo punto',
        'radius': 80,
        'latitude': defaultLocation.latitude,
        'longitude': defaultLocation.longitude - 0.005,
        'groupId': 20,
        'createdAt': '2026-08-02T00:00:00Z',
        'color': 'BLUE',
      });
      var now = DateTime.utc(2026, 9, 22, 17);
      final preferences = AppPreferencesService();
      final group = GroupProvider(GroupService(api), preferences)
        ..activeGroup = GetGroupsResponseModel(id: 20, name: 'Familia')
        ..groupDetails = const GetGroupResponseModel(
          id: 20,
          name: 'Familia',
          shareLocationMandatorily: false,
          invitationCode: 'ABCDEF',
          members: [],
        );
      final points = PointOfInterestProvider(
        PointOfInterestService(api),
        clock: () => now,
      );
      final push = PushNotificationService(
        NotificationApiService(api),
        preferences,
      );
      final auth = AuthProvider(
        AuthService(
          api,
          SessionStorageService(),
          push,
          BackgroundLocationService(),
        ),
        _NoopSessionStateCleanup(),
      );
      final socket = TestSocket();
      final navigationLocation = TestNavigationLocationService();
      final navigation = NavigationProvider(
        RouteService(api),
        navigationLocation,
      );
      await points.loadPoints(20);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationProvider.overrideWith(StaticLocation.new),
            locationSocketServiceProvider.overrideWithValue(socket),
          ],
          child: provider.MultiProvider(
            providers: [
              provider.ChangeNotifierProvider.value(value: group),
              provider.ChangeNotifierProvider.value(value: points),
              provider.ChangeNotifierProvider.value(value: auth),
              provider.ChangeNotifierProvider.value(value: navigation),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final debugToggle = find.byKey(const ValueKey('debug-gps-toggle'));
      expect(debugToggle, findsOneWidget);
      await tester.tap(debugToggle);
      await tester.pumpAndSettle();
      expect(find.text('DEBUG GPS · ON'), findsOneWidget);

      final debugMap = tester.widget<LocationMap>(find.byType(LocationMap));
      expect(debugMap.onTap, isNotNull);
      debugMap.onTap!(
        LatLng(
          defaultLocation.latitude - 0.005,
          defaultLocation.longitude - 0.005,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        navigation.currentLocation?.latitude,
        closeTo(defaultLocation.latitude - 0.005, 0.000001),
      );
      expect(
        tester
            .widget<LocationMap>(find.byType(LocationMap))
            .navigationLocation
            ?.longitude,
        closeTo(defaultLocation.longitude - 0.005, 0.000001),
      );

      await tester.tap(debugToggle);
      await tester.pumpAndSettle();
      expect(find.text('DEBUG GPS · OFF'), findsOneWidget);
      expect(navigation.currentLocation, isNull);

      await tester.tap(find.byTooltip('Agregar punto de interés'));
      await tester.pumpAndSettle();
      expect(find.text('Punto de encuentro temporal'), findsOneWidget);
      await tester.tap(find.text('Punto de encuentro temporal'));
      await tester.pumpAndSettle();
      expect(find.text('Crear punto de encuentro'), findsOneWidget);
      expect(find.text('Vigencia *'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      Future<void> expandPoints() async {
        final tile = find.byType(ExpansionTile);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }

      await expandPoints();
      expect(find.text('Colegio'), findsNWidgets(2));
      expect(find.text('Parque'), findsNWidgets(2));
      expect(find.text('Punto de encuentro'), findsOneWidget);
      expect(find.text('Radio: 100 m'), findsOneWidget);
      expect(find.text('Cómo llegar'), findsNWidgets(2));
      expect(find.byTooltip('Editar punto de interés'), findsNWidgets(2));
      expect(find.byTooltip('Eliminar punto de interés'), findsNWidgets(2));
      expect(
        tester.widget<LocationMap>(find.byType(LocationMap)).onPointTap,
        isNotNull,
      );
      expect(api.routeCalls, 0);

      final destination = points.points.firstWhere((point) => point.id == 1);
      final normalMap = tester.widget<LocationMap>(find.byType(LocationMap));
      normalMap.onPointTap!(destination);
      await tester.pumpAndSettle();
      expect(
        normalMap.controller!.camera.center.latitude,
        closeTo(destination.latitude, 0.000001),
      );
      expect(
        normalMap.controller!.camera.center.longitude,
        closeTo(destination.longitude, 0.000001),
      );
      expect(find.text('Colegio'), findsNWidgets(3));
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump();
      expect(find.text('Colegio'), findsNWidgets(2));

      expect(
        await navigation.start(
          point: destination,
          selectedMode: RouteMode.walking,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Agregar punto de interés'), findsNothing);
      expect(find.byTooltip('Editar punto de interés'), findsNothing);
      expect(find.byTooltip('Eliminar punto de interés'), findsNothing);
      expect(find.text('Cómo llegar'), findsNothing);
      final navigationMap = tester.widget<LocationMap>(
        find.byType(LocationMap),
      );
      expect(navigationMap.onPointTap, isNull);
      expect(navigationMap.destinationPointId, 1);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      final centerBeforeTap = navigationMap.controller!.camera.center;
      final parkMarker = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Parque' &&
            widget.style?.fontSize == 13,
      );
      expect(parkMarker, findsOneWidget);
      await tester.tap(parkMarker);
      final centerAfterTap = navigationMap.controller!.camera.center;
      expect(
        centerAfterTap.latitude,
        closeTo(centerBeforeTap.latitude, 0.000001),
      );
      expect(
        centerAfterTap.longitude,
        closeTo(centerBeforeTap.longitude, 0.000001),
      );

      expect(
        await points.update(
          20,
          1,
          const UpdatePointOfInterestRequest(name: 'UTN'),
        ),
        isTrue,
      );
      await tester.pump();
      expect(navigation.destination?.name, 'UTN');
      expect(api.routeCalls, 1);

      api.additionalPoints.clear();
      await points.loadPoints(20);
      expect(points.points, hasLength(1));
      expect(navigation.active, isTrue);
      expect(await points.delete(20, 1), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      expect(api.deleted, isTrue);
      expect(points.points, isEmpty);
      expect(navigation.active, isFalse);
      expect(navigation.remainingPoints, isEmpty);
      expect(navigationLocation.cancellations, 1);
      expect(find.text('El destino ya no está disponible.'), findsOneWidget);
      expect(find.text('Punto de encuentro'), findsNothing);
      await tester.pumpAndSettle();

      api.point = {
        ...api.point,
        'isTemporary': true,
        'endTime': now.add(const Duration(milliseconds: 250)).toIso8601String(),
      };
      await points.loadPoints(20);
      expect(points.points, hasLength(1));
      expect(
        await navigation.start(
          point: points.points.single,
          selectedMode: RouteMode.walking,
        ),
        isTrue,
      );
      await tester.pump();
      now = now.add(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(points.points, isEmpty);
      expect(navigation.active, isFalse);
      expect(navigation.remainingPoints, isEmpty);
      expect(navigationLocation.cancellations, 2);
      expect(find.text('El destino ya no está disponible.'), findsOneWidget);
      await tester.pumpAndSettle();

      // Expanded group panel must not intercept the offscreen member's tap.
      final sheet = tester
          .widgetList<DraggableScrollableSheet>(
            find.byType(DraggableScrollableSheet),
          )
          .single;
      sheet.controller!.jumpTo(sheet.maxChildSize);
      await tester.pumpAndSettle();
      final controller = tester
          .widget<LocationMap>(find.byType(LocationMap))
          .controller!;
      final zoom = controller.camera.zoom;
      final offscreenMember = find
          .ancestor(
            of: find.byIcon(Icons.navigation),
            matching: find.byType(GestureDetector),
          )
          .first;
      await tester.tap(offscreenMember);
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.longitude,
        closeTo(defaultLocation.longitude + 1, 0.000001),
      );
      expect(controller.camera.zoom, zoom);
      expect(sheet.controller!.size, sheet.maxChildSize);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      group.dispose();
      points.dispose();
      auth.dispose();
      navigation.dispose();
      await navigationLocation.close();
      push.dispose();
      await socket.dispose();
    },
  );

  testWidgets('cancelar navegación restaura las acciones de POI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryApi();
    final preferences = AppPreferencesService();
    final group = GroupProvider(GroupService(api), preferences)
      ..activeGroup = GetGroupsResponseModel(id: 20, name: 'Familia')
      ..groupDetails = const GetGroupResponseModel(
        id: 20,
        name: 'Familia',
        shareLocationMandatorily: false,
        invitationCode: 'ABCDEF',
        members: [],
      );
    final points = PointOfInterestProvider(PointOfInterestService(api));
    final push = PushNotificationService(
      NotificationApiService(api),
      preferences,
    );
    final auth = AuthProvider(
      AuthService(
        api,
        SessionStorageService(),
        push,
        BackgroundLocationService(),
      ),
      _NoopSessionStateCleanup(),
    );
    final socket = TestSocket();
    final navigationLocation = TestNavigationLocationService();
    final navigation = NavigationProvider(
      RouteService(api),
      navigationLocation,
    );
    await points.loadPoints(20);
    expect(
      await navigation.start(
        point: points.points.single,
        selectedMode: RouteMode.walking,
      ),
      isTrue,
    );

    Widget buildScreen() => ProviderScope(
      overrides: [
        locationProvider.overrideWith(StaticLocation.new),
        locationSocketServiceProvider.overrideWithValue(socket),
      ],
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider.value(value: group),
          provider.ChangeNotifierProvider.value(value: points),
          provider.ChangeNotifierProvider.value(value: auth),
          provider.ChangeNotifierProvider.value(value: navigation),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final tile = find.byType(ExpansionTile);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Agregar punto de interés'), findsNothing);
    expect(find.byTooltip('Editar punto de interés'), findsNothing);
    expect(find.byTooltip('Eliminar punto de interés'), findsNothing);
    expect(find.text('Cómo llegar'), findsNothing);
    expect(
      tester.widget<LocationMap>(find.byType(LocationMap)).onPointTap,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await navigation.cancel();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final restoredTile = find.byType(ExpansionTile);
    await tester.ensureVisible(restoredTile);
    await tester.tap(restoredTile);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Agregar punto de interés'), findsOneWidget);
    expect(find.byTooltip('Editar punto de interés'), findsOneWidget);
    expect(find.byTooltip('Eliminar punto de interés'), findsOneWidget);
    expect(find.text('Cómo llegar'), findsOneWidget);
    expect(
      tester.widget<LocationMap>(find.byType(LocationMap)).onPointTap,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    group.dispose();
    points.dispose();
    auth.dispose();
    navigation.dispose();
    await navigationLocation.close();
    push.dispose();
    await socket.dispose();
  });
}
