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

  test('keeps tracking when one of two sharing groups remains enabled', () {
    const twoGroups = <LocationSharingModel>[
      LocationSharingModel(
        memberId: 1,
        groupId: 2,
        locationSharingEnabled: false,
        shareLocationMandatorily: false,
        effectiveLocationSharing: false,
      ),
      LocationSharingModel(
        memberId: 1,
        groupId: 3,
        locationSharingEnabled: true,
        shareLocationMandatorily: false,
        effectiveLocationSharing: true,
      ),
    ];

    expect(
      shouldRunLocationTracking(twoGroups, LocationPermissionStatus.always),
      isTrue,
    );
  });

  test('stops after the last sharing group is disabled', () {
    const disabled = <LocationSharingModel>[
      LocationSharingModel(
        memberId: 1,
        groupId: 2,
        locationSharingEnabled: false,
        shareLocationMandatorily: false,
        effectiveLocationSharing: false,
      ),
      LocationSharingModel(
        memberId: 1,
        groupId: 3,
        locationSharingEnabled: false,
        shareLocationMandatorily: false,
        effectiveLocationSharing: false,
      ),
    ];

    expect(
      shouldRunLocationTracking(disabled, LocationPermissionStatus.always),
      isFalse,
    );
  });

  test('denied and whileInUse never start persistent tracking', () {
    expect(
      shouldRunLocationTracking(enabled, LocationPermissionStatus.denied),
      isFalse,
    );
    expect(
      shouldRunLocationTracking(enabled, LocationPermissionStatus.whileInUse),
      isFalse,
    );
  });
}
