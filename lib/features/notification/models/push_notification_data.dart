class PushNotificationData {
  final String type;
  final String? memberUserId;
  final String? groupId;
  final String? pointOfInterestId;
  final String? eventId;

  const PushNotificationData({
    required this.type,
    this.memberUserId,
    this.groupId,
    this.pointOfInterestId,
    this.eventId,
  });

  factory PushNotificationData.fromMap(Map<String, dynamic> data) {
    return PushNotificationData(
      memberUserId: data['memberUserId']?.toString(),
      type: data['type']?.toString() ?? '',
      groupId: data['groupId']?.toString(),
      pointOfInterestId: data['pointOfInterestId']?.toString(),
      eventId: data['eventId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    if (memberUserId != null) 'memberUserId': memberUserId,
    if (groupId != null) 'groupId': groupId,
    if (pointOfInterestId != null) 'pointOfInterestId': pointOfInterestId,
    if (eventId != null) 'eventId': eventId,
  };
}
