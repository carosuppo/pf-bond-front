class BlockedUserModel {
  final int userId;
  final String name;
  final String? profilePhoto;
  final DateTime blockedAt;

  const BlockedUserModel({
    required this.userId,
    required this.name,
    required this.profilePhoto,
    required this.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      userId: json['userId'] as int,
      name: json['name'] as String,
      profilePhoto: json['profilePhoto'] as String?,
      blockedAt: DateTime.parse(json['blockedAt'] as String),
    );
  }
}
