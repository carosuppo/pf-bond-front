import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses all point-of-interest group events', () {
    final data = <String, dynamic>{'groupId': 3, 'pointOfInterestId': 5};

    expect(
      parseLocationSocketEvent('pointOfInterestCreated', data),
      isA<PointOfInterestCreated>(),
    );
    expect(
      parseLocationSocketEvent('pointOfInterestUpdated', data),
      isA<PointOfInterestUpdated>(),
    );
    expect(
      parseLocationSocketEvent('pointOfInterestDeleted', data),
      isA<PointOfInterestDeleted>(),
    );
  });

  test('continues parsing existing location events', () {
    final updated = parseLocationSocketEvent('memberLocationUpdated', {
      'groupId': 3,
      'memberId': 2,
      'userId': 8,
      'name': 'Ana',
      'latitude': -34.6,
      'longitude': -58.4,
      'accuracy': null,
      'capturedAt': null,
      'lastSeenAt': null,
    });

    expect(updated, isA<MemberLocationUpdated>());
    expect((updated! as MemberLocationUpdated).member.name, 'Ana');
  });

  test('parses group deletion events', () {
    final event = parseLocationSocketEvent('groupDeleted', {'groupId': 12});

    expect(event, isA<GroupDeleted>());
    expect((event! as GroupDeleted).groupId, 12);
  });

  test('parses group membership departure events', () {
    final event = parseLocationSocketEvent('memberLeft', {
      'groupId': 12,
      'memberId': 4,
      'userId': 8,
    });

    expect(event, isA<MemberLeft>());
    final memberLeft = event! as MemberLeft;
    expect(memberLeft.memberId, 4);
    expect(memberLeft.userId, 8);
  });
}
