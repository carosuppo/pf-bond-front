import 'dart:math' as math;
import 'package:bond_front/features/location/constants/default_location.dart';
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
  List<PointOfInterest> points = const [],
  LatLng? previewPoint,
  PointOfInterestColor previewColor = PointOfInterestColor.blue,
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
              controller: controller,
              onTap: onTap,
              points: points,
              previewPoint: previewPoint,
              previewRadius: 100,
              previewColor: previewColor,
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
          latitude: target.latitude,
          longitude: target.longitude,
          lastSeenAt: DateTime.now().subtract(Duration(minutes: stale ? 4 : 1)),
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
            .ancestor(of: arrow, matching: find.byType(Container))
            .first;
        final circle = tester.widget<Container>(circleFinder);
        final color = buildDistinctMarkerColors([2])[2]!;
        expect(
          (circle.decoration as BoxDecoration).color,
          stale ? color.withAlpha(110) : color,
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
    await pumpMap(tester, controller, state: state);
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
    'POI flag and circle use their color; people remain pins; preview uses its color',
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
      expect(iconAt(0).icon, Icons.location_pin);
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
}
