import '../models/location_socket_event.dart';
import '../models/member_location_model.dart';

Map<int, MemberLocationModel> reduceMemberLocations(
  Map<int, MemberLocationModel> current,
  LocationSocketEvent event,
  int? activeGroupId,
) {
  if (event is MemberLocationUpdated && event.groupId == activeGroupId) {
    return <int, MemberLocationModel>{
      ...current,
      event.member.memberId: event.member,
    };
  }
  if (event is MemberLocationRemoved && event.groupId == activeGroupId) {
    return <int, MemberLocationModel>{...current}..remove(event.memberId);
  }
  return current;
}
