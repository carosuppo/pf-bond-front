import 'member_location_model.dart';

sealed class LocationSocketEvent {
  const LocationSocketEvent();
}

class LocationSocketAuthenticated extends LocationSocketEvent {
  const LocationSocketAuthenticated();
}

class MemberLocationUpdated extends LocationSocketEvent {
  final int groupId;

  final MemberLocationModel member;

  const MemberLocationUpdated({required this.groupId, required this.member});
}

class MemberLocationRemoved extends LocationSocketEvent {
  final int groupId;
  final int memberId;
  final int userId;

  const MemberLocationRemoved({
    required this.groupId,
    required this.memberId,
    required this.userId,
  });
}

class MemberLocationHeartbeat extends LocationSocketEvent {
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

sealed class PointOfInterestSocketEvent extends LocationSocketEvent {
  final int groupId;
  final int pointOfInterestId;

  const PointOfInterestSocketEvent({
    required this.groupId,
    required this.pointOfInterestId,
  });
}

class PointOfInterestCreated extends PointOfInterestSocketEvent {
  const PointOfInterestCreated({
    required super.groupId,
    required super.pointOfInterestId,
  });
}

class PointOfInterestUpdated extends PointOfInterestSocketEvent {
  const PointOfInterestUpdated({
    required super.groupId,
    required super.pointOfInterestId,
  });
}

class PointOfInterestDeleted extends PointOfInterestSocketEvent {
  const PointOfInterestDeleted({
    required super.groupId,
    required super.pointOfInterestId,
  });
}

LocationSocketEvent? parseLocationSocketEvent(
  String event,
  Map<String, dynamic> data,
) {
  return switch (event) {
    'memberLocationUpdated' => MemberLocationUpdated(
      groupId: data['groupId'] as int,
      member: MemberLocationModel.fromJson(data),
    ),
    'memberLocationRemoved' => MemberLocationRemoved(
      groupId: data['groupId'] as int,
      memberId: data['memberId'] as int,
      userId: data['userId'] as int,
    ),
    'memberLocationHeartbeat' => MemberLocationHeartbeat(
      groupId: data['groupId'] as int,
      memberId: data['memberId'] as int,
      userId: data['userId'] as int,
      lastSeenAt: DateTime.parse(data['lastSeenAt'] as String),
    ),
    'pointOfInterestCreated' => PointOfInterestCreated(
      groupId: data['groupId'] as int,
      pointOfInterestId: data['pointOfInterestId'] as int,
    ),
    'pointOfInterestUpdated' => PointOfInterestUpdated(
      groupId: data['groupId'] as int,
      pointOfInterestId: data['pointOfInterestId'] as int,
    ),
    'pointOfInterestDeleted' => PointOfInterestDeleted(
      groupId: data['groupId'] as int,
      pointOfInterestId: data['pointOfInterestId'] as int,
    ),
    _ => null,
  };
}
