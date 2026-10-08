import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:bond_front/features/location/providers/location_provider.dart';
import 'package:bond_front/features/location/widgets/location_sharing_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Location extends LocationProvider {
  _Location({this.enabled = false});
  final bool enabled;
  int changes = 0;
  int batterySettings = 0;

  @override
  LocationState build() => LocationState.initial().copyWith(
    permissionStatus: LocationPermissionStatus.always,
    sharing: [
      LocationSharingModel(
        memberId: 1,
        groupId: 10,
        locationSharingEnabled: enabled,
        shareLocationMandatorily: false,
        effectiveLocationSharing: enabled,
      ),
    ],
  );

  @override
  Future<bool> setGroupSharing(int groupId, bool enabled) async {
    changes++;
    return true;
  }

  @override
  Future<void> openBatterySettings() async {
    batterySettings++;
  }
}

Future<void> _pump(WidgetTester tester, _Location location) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [locationProvider.overrideWith(() => location)],
        child: const MaterialApp(
          home: Scaffold(body: LocationSharingControls(groupId: 10)),
        ),
      ),
    );

void main() {
  testWidgets('sharing requires accepting disclosure before permission flow', (
    tester,
  ) async {
    final location = _Location();
    await _pump(tester, location);
    expect(location.changes, 0);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(location.changes, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(location.changes, 0);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(location.changes, 1);
  });

  testWidgets('battery settings are optional and never open automatically', (
    tester,
  ) async {
    final location = _Location(enabled: true);
    await _pump(tester, location);
    expect(location.batterySettings, 0);
    await tester.tap(find.text('Batería y ubicación continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(location.batterySettings, 0);
    await tester.tap(find.text('Batería y ubicación continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(location.batterySettings, 1);
  });
}
