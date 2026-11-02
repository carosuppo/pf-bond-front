import 'package:bond_front/features/location/models/location_socket_event.dart';
import 'package:bond_front/features/point_of_interest/services/point_of_interest_realtime_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final event in <PointOfInterestSocketEvent>[
    const PointOfInterestCreated(groupId: 3, pointOfInterestId: 1),
    const PointOfInterestUpdated(groupId: 3, pointOfInterestId: 1),
    const PointOfInterestDeleted(groupId: 3, pointOfInterestId: 1),
  ]) {
    test('${event.runtimeType} refreshes the currently viewed group', () async {
      final loadedGroups = <int>[];

      await refreshPointsForSocketEvent(
        event: event,
        viewingGroupId: 3,
        loadPoints: (groupId) async => loadedGroups.add(groupId),
      );

      expect(loadedGroups, [3]);
    });
  }

  test('does not refresh for a POI event from another group', () async {
    final loadedGroups = <int>[];

    await refreshPointsForSocketEvent(
      event: const PointOfInterestCreated(groupId: 4, pointOfInterestId: 1),
      viewingGroupId: 3,
      loadPoints: (groupId) async => loadedGroups.add(groupId),
    );

    expect(loadedGroups, isEmpty);
  });

  test('does not mix location events into POI refreshes', () async {
    final loadedGroups = <int>[];

    await refreshPointsForSocketEvent(
      event: const MemberLocationRemoved(groupId: 3, memberId: 2, userId: 2),
      viewingGroupId: 3,
      loadPoints: (groupId) async => loadedGroups.add(groupId),
    );

    expect(loadedGroups, isEmpty);
  });
}
