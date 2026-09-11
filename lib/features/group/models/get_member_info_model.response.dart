class GetMemberInfoResponseModel {
  final int memberId;
  final String name;
  final DateTime? lastSeenAt;

  const GetMemberInfoResponseModel({
    required this.memberId,
    required this.name,
    required this.lastSeenAt,
  });

  factory GetMemberInfoResponseModel.fromJson(Map<String, dynamic> json) {
    return GetMemberInfoResponseModel(
      memberId: json['memberId'] as int,
      name: json['name'] as String,
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
    );
  }
}
