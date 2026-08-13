import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/location_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking is unnecessary without effective sharing', () {
    final state = LocationState.initial().copyWith(
      sharing: const <LocationSharingModel>[
        LocationSharingModel(
          memberId: 1,
          groupId: 2,
          locationSharingEnabled: false,
          shareLocationMandatorily: false,
          effectiveLocationSharing: false,
        ),
      ],
    );
    expect(state.hasEffectiveSharing, isFalse);
    expect(state.isTracking, isFalse);
  });

  test('mandatory sharing requires tracking when permission is always', () {
    final state = LocationState.initial().copyWith(
      permissionStatus: LocationPermissionStatus.always,
      sharing: const <LocationSharingModel>[
        LocationSharingModel(
          memberId: 1,
          groupId: 2,
          locationSharingEnabled: false,
          shareLocationMandatorily: true,
          effectiveLocationSharing: true,
        ),
      ],
    );
    expect(state.hasEffectiveSharing, isTrue);
  });
}
