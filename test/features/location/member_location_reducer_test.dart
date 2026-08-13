import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:bond_front/features/location/models/member_location_model.dart';
import 'package:bond_front/features/location/utils/member_location_reducer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const member = MemberLocationModel(
    memberId: 3,
    userId: 4,
    name: 'Alex',
    latitude: 1,
    longitude: 2,
  );

  test('adds and updates a member for the active group', () {
    final result = reduceMemberLocations(
      const <int, MemberLocationModel>{},
      const MemberLocationUpdated(groupId: 9, member: member),
      9,
    );
    expect(result, <int, MemberLocationModel>{3: member});
  });

  test('removes a member immediately', () {
    final result = reduceMemberLocations(
      const <int, MemberLocationModel>{3: member},
      const MemberLocationRemoved(groupId: 9, memberId: 3, userId: 4),
      9,
    );
    expect(result, isEmpty);
  });

  test('ignores events from another group', () {
    final initial = const <int, MemberLocationModel>{3: member};
    final result = reduceMemberLocations(
      initial,
      const MemberLocationRemoved(groupId: 10, memberId: 3, userId: 4),
      9,
    );
    expect(identical(result, initial), isTrue);
  });
}
