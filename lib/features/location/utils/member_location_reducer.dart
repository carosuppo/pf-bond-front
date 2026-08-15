import '../models/location_socket_event.dart';
import '../models/member_location_model.dart';

Map<int, MemberLocationModel>
reduceMemberLocations(
  Map<int, MemberLocationModel> current,
  LocationSocketEvent event,
  int? activeGroupId,
) {
  if (
      event is MemberLocationUpdated &&
      event.groupId == activeGroupId) {
    return <int, MemberLocationModel>{
      ...current,
      event.member.memberId:
          event.member,
    };
  }

  if (
      event is MemberLocationRemoved &&
      event.groupId == activeGroupId) {
    return <int, MemberLocationModel>{
      ...current,
    }..remove(
        event.memberId,
      );
  }

  if (
      event is MemberLocationHeartbeat &&
      event.groupId == activeGroupId) {
    final member =
        current[event.memberId];

    if (member == null) {
      return current;
    }

    return <int, MemberLocationModel>{
      ...current,

      event.memberId:
          member.copyWith(
        lastSeenAt:
            event.lastSeenAt,
      ),
    };
  }

  return current;
}
