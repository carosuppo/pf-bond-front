class PushNotificationData {
  final String type;
  final String? memberUserId;
  final String? groupId;
  final String? pointOfInterestId;

  const PushNotificationData({
    required this.type,
    this.memberUserId,
    this.groupId,
    this.pointOfInterestId,
  });

  factory PushNotificationData.fromMap(Map<String, dynamic> data) {
    return PushNotificationData(
      memberUserId: data['memberUserId']?.toString(),
      type: data['type']?.toString() ?? '',
      groupId: data['groupId']?.toString(),
      pointOfInterestId: data['pointOfInterestId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    if (memberUserId != null) 'memberUserId': memberUserId,
    if (groupId != null) 'groupId': groupId,
    if (pointOfInterestId != null) 'pointOfInterestId': pointOfInterestId,
  };
}
