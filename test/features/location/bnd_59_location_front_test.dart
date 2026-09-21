import 'package:bond_front/features/location/constants/location_tracking_config.dart';
import 'package:bond_front/core/theme/app_colors.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/widgets/location_map.dart';
import 'package:bond_front/core/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationProvider extends LocationProvider {
  _FakeLocationProvider(this.initialState);

  final LocationState initialState;

  @override
  LocationState build() => initialState;
}

LocationState _stateWithMembers(Map<int, MemberLocationModel> members) {
  return LocationState(
    isLoading: false,
    isTracking: false,
    permissionStatus: LocationPermissionStatus.unknown,
    sharing: const [],
    visibleMembers: members,
    activeGroupId: 20,
  );
}

Future<void> _pumpMap(WidgetTester tester, LocationState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationProvider.overrideWith(() => _FakeLocationProvider(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: LocationMap(groupId: 20),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
}

Future<void> _disposeMap(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());

  await tester.pump();
}

void main() {
  testWidgets(
    'BND-59 FE-01 muestra miembros con ubicacion antigua y atenua su avatar',
    (tester) async {
      final now = DateTime.now();

      final activeA = MemberLocationModel(
        memberId: 2,
        userId: 2,
        name: 'Ana',
        latitude: -34.6037,
        longitude: -58.3816,
        lastSeenAt: now.subtract(const Duration(minutes: 1)),
      );

      final stale = MemberLocationModel(
        memberId: 3,
        userId: 3,
        name: 'Antiguo',
        latitude: -34.61,
        longitude: -58.39,
        lastSeenAt: now.subtract(
          Duration(minutes: LocationTrackingConfig.staleAfter.inMinutes + 1),
        ),
      );

      final activeB = MemberLocationModel(
        memberId: 4,
        userId: 4,
        name: 'Luis',
        latitude: -34.615,
        longitude: -58.4,
        lastSeenAt: now.subtract(const Duration(minutes: 2)),
      );

      await _pumpMap(
        tester,
        _stateWithMembers({
          activeA.memberId: activeA,
          stale.memberId: stale,
          activeB.memberId: activeB,
        }),
      );

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));

      expect(markerLayer.markers, hasLength(3));

      final firstMarker = markerLayer.markers[0];

      final staleMarker = markerLayer.markers[1];

      // Verificamos la posición geográfica de Ana.
      expect(firstMarker.point.latitude, activeA.latitude);

      expect(firstMarker.point.longitude, activeA.longitude);

      expect(staleMarker.point.latitude, stale.latitude);

      expect(staleMarker.point.longitude, stale.longitude);

      final staleColumn = staleMarker.child as Column;
      final staleAvatar = staleColumn.children[1] as Opacity;

      expect(staleAvatar.opacity, 0.5);
      expect(staleAvatar.child, isA<UserAvatar>());

      final thirdMarker = markerLayer.markers[2];

      expect(thirdMarker.point.latitude, activeB.latitude);

      final firstColumn = firstMarker.child as Column;

      final thirdColumn = thirdMarker.child as Column;

      final firstName = firstColumn.children[0] as Text;

      final thirdName = thirdColumn.children[0] as Text;

      final firstAvatar = firstColumn.children[1] as UserAvatar;

      final thirdAvatar = thirdColumn.children[1] as UserAvatar;

      expect(firstName.data, 'Ana');

      expect(thirdName.data, 'Luis');

      expect(firstAvatar.borderColor, AppColors.primary);

      expect(thirdAvatar.borderColor, AppColors.primary);

      await _disposeMap(tester);
    },
  );

  testWidgets(
    'BND-59 FE-02 mantiene el mapa visible cuando no hay miembros visibles',
    (tester) async {
      await _pumpMap(
        tester,
        _stateWithMembers(const <int, MemberLocationModel>{}),
      );

      // El mapa debe seguir existiendo.
      expect(find.byType(FlutterMap), findsOneWidget);

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));

      // No debe haber marcadores de miembros.
      expect(markerLayer.markers, isEmpty);

      await _disposeMap(tester);
    },
  );
}
