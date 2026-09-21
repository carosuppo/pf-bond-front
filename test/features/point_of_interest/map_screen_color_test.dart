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
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/screens/map_screen.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/location/services/location_socket_service.dart';
import 'package:bond_front/features/location/widgets/location_map.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:bond_front/features/point_of_interest/providers/point_of_interest_provider.dart';
import 'package:bond_front/features/point_of_interest/services/point_of_interest_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool deleted = false;
  @override
  Future<List<Map<String, dynamic>>> authenticatedGetList(String path) async =>
      [Map.of(point)];
  @override
  Future<Map<String, dynamic>> authenticatedPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    point = {...point, ...body};
    return Map.of(point);
  }

  @override
  Future<void> authenticatedDelete(String path) async {
    deleted = true;
  }
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
  testWidgets('screen renders point details and deletes a point', (
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
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> expandPoints() async {
      final tile = find.byType(ExpansionTile);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    await expandPoints();
    expect(find.text('Colegio'), findsNWidgets(2));
    expect(find.text('Punto de encuentro'), findsOneWidget);
    expect(find.text('Radio: 100 m'), findsOneWidget);
    final deleteButton = find.byTooltip('Eliminar punto de interés');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este punto de interés?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(api.deleted, isTrue);
    expect(points.points, isEmpty);
    expect(find.text('Punto de encuentro'), findsNothing);

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
    await tester.tap(find.byIcon(Icons.navigation));
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
    push.dispose();
    await socket.dispose();
  });
}
