import 'member_location_model.dart';

sealed class LocationSocketEvent {
  const LocationSocketEvent();
}

class LocationSocketAuthenticated
    extends LocationSocketEvent {
  const LocationSocketAuthenticated();
}

class MemberLocationUpdated
    extends LocationSocketEvent {
  final int groupId;

  final MemberLocationModel member;

  const MemberLocationUpdated({
    required this.groupId,
    required this.member,
  });
}

class MemberLocationRemoved
    extends LocationSocketEvent {
  final int groupId;
  final int memberId;
  final int userId;

  const MemberLocationRemoved({
    required this.groupId,
    required this.memberId,
    required this.userId,
  });
}

class MemberLocationHeartbeat
    extends LocationSocketEvent {
  final int groupId;
  final int memberId;
  final int userId;
  final DateTime lastSeenAt;

  const MemberLocationHeartbeat({
    required this.groupId,
    required this.memberId,
    required this.userId,
    required this.lastSeenAt,
  });
}