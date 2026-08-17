class JoinGroupRequest {
  final String invitationCode;

  const JoinGroupRequest({required this.invitationCode});

  Map<String, dynamic> toJson() {
    return {'invitationCode': invitationCode};
  }
}
