import 'package:bond_front/features/location/models/location_permission_status.dart';
import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/utils/location_tracking_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const enabled = <LocationSharingModel>[
    LocationSharingModel(
      memberId: 1,
      groupId: 2,
      locationSharingEnabled: true,
      shareLocationMandatorily: false,
      effectiveLocationSharing: true,
    ),
  ];

  test('starts tracking only with effective sharing and always permission', () {
    expect(
      shouldRunLocationTracking(enabled, LocationPermissionStatus.always),
      isTrue,
    );
    expect(
      shouldRunLocationTracking(enabled, LocationPermissionStatus.whileInUse),
      isFalse,
    );
  });

  test('stops tracking when no group effectively shares', () {
    expect(
      shouldRunLocationTracking(
        const <LocationSharingModel>[],
        LocationPermissionStatus.always,
      ),
      isFalse,
    );
  });
}
