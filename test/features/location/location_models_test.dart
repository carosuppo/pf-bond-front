import 'package:bond_front/features/location/models/location_sharing_model.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps sharing state from backend JSON', () {
    final model = LocationSharingModel.fromJson(<String, dynamic>{
      'memberId': 1,
      'groupId': 2,
      'locationSharingEnabled': false,
      'shareLocationMandatorily': true,
      'effectiveLocationSharing': true,
    });
    expect(model.groupId, 2);
    expect(model.locationSharingEnabled, isFalse);
    expect(model.effectiveLocationSharing, isTrue);
  });

  test('maps nullable member location fields', () {
    final model = MemberLocationModel.fromJson(<String, dynamic>{
      'memberId': 3,
      'userId': 4,
      'name': 'Alex',
      'latitude': -34.6,
      'longitude': -58.4,
      'accuracy': null,
      'capturedAt': null,
    });
    expect(model.latitude, -34.6);
    expect(model.accuracy, isNull);
    expect(model.capturedAt, isNull);
  });
}
