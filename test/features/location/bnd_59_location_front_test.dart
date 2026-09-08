import 'package:bond_front/features/location/constants/location_tracking_config.dart';
import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/widgets/location_map.dart';
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
    'BND-59 FE-01 muestra solo miembros activos, en su posicion y con colores distintos',
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

      final expired = MemberLocationModel(
        memberId: 3,
        userId: 3,
        name: 'Vencido',
        latitude: -34.61,
        longitude: -58.39,
        lastSeenAt: now.subtract(
          Duration(minutes: LocationTrackingConfig.hideAfter.inMinutes + 1),
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
          expired.memberId: expired,
          activeB.memberId: activeB,
        }),
      );

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));

      // Solo deben existir los dos miembros activos.
      expect(markerLayer.markers, hasLength(2));

      final firstMarker = markerLayer.markers[0];

      final secondMarker = markerLayer.markers[1];

      // Verificamos la posición geográfica de Ana.
      expect(firstMarker.point.latitude, activeA.latitude);

      expect(firstMarker.point.longitude, activeA.longitude);

      // Verificamos la posición geográfica de Luis.
      expect(secondMarker.point.latitude, activeB.latitude);

      expect(secondMarker.point.longitude, activeB.longitude);

      // Inspeccionamos directamente el contenido
      // de los marcadores.
      final firstColumn = firstMarker.child as Column;

      final secondColumn = secondMarker.child as Column;

      final firstIcon = firstColumn.children[0] as Icon;

      final secondIcon = secondColumn.children[0] as Icon;

      final firstName = firstColumn.children[1] as Text;

      final secondName = secondColumn.children[1] as Text;

      // Los miembros visibles deben ser Ana y Luis.
      expect(firstName.data, 'Ana');

      expect(secondName.data, 'Luis');

      // Cada miembro debe tener un color distinto.
      expect(firstIcon.color, isNot(equals(secondIcon.color)));

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
