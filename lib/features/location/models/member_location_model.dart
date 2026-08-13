class MemberLocationModel {
  final int memberId;
  final int userId;
  final String name;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? capturedAt;

  const MemberLocationModel({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.capturedAt,
  });

  factory MemberLocationModel.fromJson(Map<String, dynamic> json) {
    return MemberLocationModel(
      memberId: json['memberId'] as int,
      userId: json['userId'] as int,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.parse(json['capturedAt'] as String),
    );
  }
}
