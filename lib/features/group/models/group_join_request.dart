class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.requesterUserId,
    required this.requesterName,
    required this.requesterProfilePhoto,
    required this.requestedAt,
  });

  final int id;
  final int groupId;
  final String groupName;
  final int requesterUserId;
  final String requesterName;
  final String? requesterProfilePhoto;
  final DateTime requestedAt;

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) {
    return GroupJoinRequest(
      id: json['id'] as int,
      groupId: json['groupId'] as int,
      groupName: json['groupName'] as String,
      requesterUserId: json['requesterUserId'] as int,
      requesterName: json['requesterName'] as String,
      requesterProfilePhoto: json['requesterProfilePhoto'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
    );
  }
}
