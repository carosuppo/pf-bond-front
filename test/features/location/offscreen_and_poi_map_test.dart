import 'dart:math' as math;
import 'package:bond_front/core/theme/app_colors.dart';
import 'package:bond_front/core/widgets/user_avatar.dart';
import 'package:bond_front/features/location/constants/default_location.dart';
import 'package:bond_front/features/location/constants/location_tracking_config.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/location_model.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/utils/marker_colors.dart';
import 'package:bond_front/features/location/widgets/location_map.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class FakeLocation extends LocationProvider {
  FakeLocation(this.initial);
  final LocationState initial;
  @override
  LocationState build() => initial;
}

Future<void> pumpMap(
  WidgetTester tester,
  MapController controller, {
  LocationState? state,
  ValueChanged<LatLng>? onTap,
  void Function(int memberId)? onMemberTap,
  List<PointOfInterest> points = const [],
  LatLng? previewPoint,
  PointOfInterestColor previewColor = PointOfInterestColor.blue,
  bool showOffscreenPoints = false,
  String? ownProfileName,
  List<LatLng> routePoints = const [],
  int routeFitRevision = 0,
  EdgeInsets routeFitPadding = EdgeInsets.zero,
  LocationModel? navigationLocation,
  int? destinationPointId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationProvider.overrideWith(
          () => FakeLocation(state ?? LocationState.initial()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 550,
            child: LocationMap(
              groupId: 20,
              ownProfileName: ownProfileName,
              controller: controller,
              onTap: onTap,
              onMemberTap: onMemberTap,
              points: points,
              showOffscreenPoints: showOffscreenPoints,
              previewPoint: previewPoint,
              previewRadius: 100,
              previewColor: previewColor,
              routePoints: routePoints,
              routeFitRevision: routeFitRevision,
              routeFitPadding: routeFitPadding,
              navigationLocation: navigationLocation,
              destinationPointId: destinationPointId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> disposeMap(WidgetTester tester, MapController controller) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  controller.dispose();
}

void main() {
  testWidgets('dibuja la ruta restante dentro del mapa', (tester) async {
    final controller = MapController();
    await pumpMap(
      tester,
      controller,
      routePoints: const [LatLng(-34.6, -58.4), LatLng(-34.61, -58.41)],
    );
    expect(find.byType(PolylineLayer), findsOneWidget);
    await disposeMap(tester, controller);
  });

  testWidgets(
    'ajusta la cámara al cambiar la ruta y preserva movimientos manuales',
    (tester) async {
      final controller = MapController();
      const origin = LatLng(-34.50, -58.55);
      const middle = LatLng(-34.60, -58.45);
      const destination = LatLng(-34.70, -58.35);
      final point = PointOfInterest(
        id: 7,
        name: 'Destino',
        radius: 50,
        latitude: destination.latitude,
        longitude: destination.longitude,
        groupId: 20,
        createdAt: DateTime(2026),
      );
      final location = LocationModel(
        latitude: origin.latitude,
        longitude: origin.longitude,
        accuracy: 5,
        timestamp: DateTime(2026),
      );

      await pumpMap(
        tester,
        controller,
        points: [point],
        routePoints: const [origin, middle, destination],
        routeFitRevision: 1,
        routeFitPadding: const EdgeInsets.fromLTRB(40, 140, 40, 100),
        navigationLocation: location,
        destinationPointId: point.id,
      );
      await tester.pump();

      final initialBounds = controller.camera.visibleBounds;
      expect(
        initialBounds.contains(origin),
        isTrue,
        reason: 'La cámara $initialBounds no contiene el origen.',
      );
      expect(
        initialBounds.contains(middle),
        isTrue,
        reason: 'La cámara $initialBounds no contiene el recorrido.',
      );
      expect(
        initialBounds.contains(destination),
        isTrue,
        reason: 'La cámara $initialBounds no contiene el destino.',
      );

      controller.move(defaultLocation, 15);
      await tester.pump();
      final manualCenter = controller.camera.center;
      final manualZoom = controller.camera.zoom;
      await pumpMap(
        tester,
        controller,
        points: [point],
        routePoints: const [middle, destination],
        routeFitRevision: 1,
        routeFitPadding: const EdgeInsets.fromLTRB(40, 140, 40, 100),
        navigationLocation: location.copyWith(
          latitude: middle.latitude,
          longitude: middle.longitude,
        ),
        destinationPointId: point.id,
      );
      await tester.pump();

      expect(controller.camera.center, manualCenter);
      expect(controller.camera.zoom, manualZoom);

      await pumpMap(
        tester,
        controller,
        points: [point],
        routePoints: const [middle, destination],
        routeFitRevision: 2,
        routeFitPadding: const EdgeInsets.fromLTRB(40, 140, 40, 100),
        navigationLocation: location.copyWith(
          latitude: middle.latitude,
          longitude: middle.longitude,
        ),
        destinationPointId: point.id,
      );
      await tester.pump();

      expect(controller.camera.center, isNot(manualCenter));
      expect(controller.camera.visibleBounds.contains(middle), isTrue);
      expect(controller.camera.visibleBounds.contains(destination), isTrue);
      await disposeMap(tester, controller);
    },
  );

  for (final stale in [false, true]) {
    testWidgets(
      'offscreen member is tappable, preserves zoom and direction/color (stale=$stale)',
      (tester) async {
        final controller = MapController();
        final target = LatLng(
          defaultLocation.latitude,
          defaultLocation.longitude + 1,
        );
        final member = MemberLocationModel(
          memberId: 2,
          userId: 2,
          name: 'Ana',
          profilePhoto: 'https://example.com/ana.jpg',
          latitude: target.latitude,
          longitude: target.longitude,
          lastSeenAt: DateTime.now().subtract(
            stale
                ? LocationTrackingConfig.staleAfter + const Duration(minutes: 1)
                : const Duration(minutes: 1),
          ),
        );
        var mapTaps = 0;
        await pumpMap(
          tester,
          controller,
          state: LocationState.initial().copyWith(visibleMembers: {2: member}),
          onTap: (_) => mapTaps++,
        );
        controller.move(defaultLocation, 12.5);
        controller.rotate(30);
        await tester.pump();
        expect(find.byIcon(Icons.navigation), findsOneWidget);
        final arrow = find.byIcon(Icons.navigation);
        final circleFinder = find
            .ancestor(
              of: find.byType(UserAvatar),
              matching: find.byType(Container),
            )
            .first;
        final circle = tester.widget<Container>(circleFinder);
        final color = buildDistinctMarkerColors([2])[2]!;
        expect(
          (circle.decoration as BoxDecoration).color,
          stale ? color.withAlpha(110) : color,
        );
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).photoUrl,
          'https://example.com/ana.jpg',
        );
        final transform = tester.widget<Transform>(
          find.ancestor(of: arrow, matching: find.byType(Transform)).first,
        );
        final projected = controller.camera.latLngToScreenOffset(target);
        final direction = projected - const Offset(200, 275);
        final angle = math.atan2(direction.dy, direction.dx) + math.pi / 2;
        expect(
          transform.transform.entry(0, 0),
          closeTo(math.cos(angle), 0.000001),
        );
        expect(
          transform.transform.entry(1, 0),
          closeTo(math.sin(angle), 0.000001),
        );
        await tester.tap(arrow);
        await tester.pump();
        expect(
          controller.camera.center.latitude,
          closeTo(target.latitude, 0.000001),
        );
        expect(
          controller.camera.center.longitude,
          closeTo(target.longitude, 0.000001),
        );
        expect(controller.camera.zoom, 12.5);
        expect(controller.camera.rotation, 30);
        expect(mapTaps, 0);
        expect(find.byIcon(Icons.navigation), findsNothing);
        await disposeMap(tester, controller);
      },
    );
  }
  testWidgets('own offscreen indicator recenters Vos at the current zoom', (
    tester,
  ) async {
    final controller = MapController();
    final state = LocationState.initial().copyWith(
      currentLocation: LocationModel(
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        accuracy: 5,
        timestamp: DateTime.now(),
      ),
      sharing: [
        const LocationSharingModel(
          memberId: 1,
          groupId: 20,
          locationSharingEnabled: true,
          shareLocationMandatorily: false,
          effectiveLocationSharing: true,
        ),
      ],
    );
    await pumpMap(tester, controller, state: state, ownProfileName: 'prueba');
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).name, 'prueba');
    controller.move(
      LatLng(defaultLocation.latitude + 1, defaultLocation.longitude),
      13.25,
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.navigation));
    await tester.pump();
    expect(controller.camera.center, defaultLocation);
    expect(controller.camera.zoom, 13.25);
    await disposeMap(tester, controller);
  });
  testWidgets('clusters members less than 50 meters apart', (tester) async {
    final controller = MapController();
    int? selectedMemberId;
    final memberA = MemberLocationModel(
      memberId: 2,
      userId: 2,
      name: 'Ana',
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude,
      lastSeenAt: DateTime.now(),
    );
    final memberB = MemberLocationModel(
      memberId: 3,
      userId: 3,
      name: 'Luis',
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude + 0.0004,
      lastSeenAt: DateTime.now(),
    );

    await pumpMap(
      tester,
      controller,
      state: LocationState.initial().copyWith(
        visibleMembers: {2: memberA, 3: memberB},
      ),
      onMemberTap: (memberId) => selectedMemberId = memberId,
    );
    await tester.pump();

    final markers = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers;
    expect(markers, hasLength(1));
    expect(find.byType(UserAvatar), findsNWidgets(2));

    final clusterContainer = markers.single.child as Container;
    final clusterWrap = clusterContainer.child as Wrap;
    expect(clusterWrap.children, hasLength(2));
    expect(clusterWrap.spacing, 5);
    expect(clusterWrap.runSpacing, 5);
    final decoration = clusterContainer.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(15));
    expect(decoration.color, isNull);
    expect(decoration.border?.top.color, AppColors.primary);

    final zoomBeforeSelection = controller.camera.zoom;
    await tester.tap(find.byType(UserAvatar).first);
    await tester.pump();
    expect(selectedMemberId, 2);
    expect(controller.camera.zoom, zoomBeforeSelection);

    await tester.tap(find.byType(UserAvatar).last);
    await tester.pump();
    expect(selectedMemberId, 3);

    await disposeMap(tester, controller);
  });
  testWidgets('empty overlay area passes taps and drag through to FlutterMap', (
    tester,
  ) async {
    final controller = MapController();
    final member = MemberLocationModel(
      memberId: 2,
      userId: 2,
      name: 'Ana',
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude + 1,
      lastSeenAt: DateTime.now(),
    );
    LatLng? tapped;
    await pumpMap(
      tester,
      controller,
      state: LocationState.initial().copyWith(visibleMembers: {2: member}),
      onTap: (point) => tapped = point,
    );
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    await tester.tapAt(const Offset(150, 250));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tapped, isNotNull);
    final previous = controller.camera.center;
    await tester.dragFrom(const Offset(150, 250), const Offset(80, 50));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.camera.center, isNot(previous));
    await disposeMap(tester, controller);
  });
  testWidgets(
    'POI flag and circle use their color; people use avatars; preview uses its color',
    (tester) async {
      final controller = MapController();
      final member = MemberLocationModel(
        memberId: 2,
        userId: 2,
        name: 'Ana',
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        lastSeenAt: DateTime.now(),
      );
      final point = PointOfInterest(
        id: 1,
        name: 'Colegio',
        radius: 100,
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        groupId: 20,
        createdAt: DateTime(2026),
        color: PointOfInterestColor.red,
      );
      await pumpMap(
        tester,
        controller,
        state: LocationState.initial().copyWith(visibleMembers: {2: member}),
        points: [point],
        previewPoint: defaultLocation,
        previewColor: PointOfInterestColor.purple,
      );
      final circles = tester
          .widget<CircleLayer>(find.byType(CircleLayer))
          .circles;
      expect(circles[0].borderColor, Colors.red);
      expect(circles[0].color, Colors.red.withAlpha(45));
      expect(circles[1].borderColor, Colors.purple);
      expect(circles[1].color, Colors.purple.withAlpha(55));
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      Icon iconAt(int i) => (markers[i].child as Column).children.first as Icon;
      expect(iconAt(1).icon, Icons.flag_rounded);
      expect(iconAt(1).color, Colors.red);
      expect(iconAt(2).icon, Icons.flag_rounded);
      expect(iconAt(2).color, Colors.purple);
      controller.move(
        LatLng(defaultLocation.latitude + 1, defaultLocation.longitude),
        15,
      );
      await tester.pump();
      expect(find.byIcon(Icons.navigation), findsOneWidget); // Only the person.
      await disposeMap(tester, controller);
    },
  );
  testWidgets(
    'offscreen POI indicator uses a flag and follows the list state',
    (tester) async {
      final controller = MapController();
      final point = PointOfInterest(
        id: 1,
        name: 'Colegio',
        radius: 100,
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude + 1,
        groupId: 20,
        createdAt: DateTime(2026),
        color: PointOfInterestColor.red,
      );

      await pumpMap(
        tester,
        controller,
        points: [point],
        showOffscreenPoints: true,
      );
      controller.move(defaultLocation, 15);
      await tester.pump();

      final offscreenFlag = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.flag_rounded &&
            widget.color == Colors.white,
      );
      expect(offscreenFlag, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == Icons.navigation &&
              widget.color == Colors.red,
        ),
        findsOneWidget,
      );

      await pumpMap(tester, controller, points: [point]);
      expect(offscreenFlag, findsNothing);
      await disposeMap(tester, controller);
    },
  );
}
