class MemberLocationModel {
  final int memberId;
  final int userId;
  final String name;

  final double latitude;
  final double longitude;

  final double? accuracy;

  final DateTime? capturedAt;
  final DateTime? lastSeenAt;

  const MemberLocationModel({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.capturedAt,
    this.lastSeenAt,
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

      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
    );
  }

  MemberLocationModel copyWith({
    int? memberId,
    int? userId,
    String? name,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? capturedAt,
    DateTime? lastSeenAt,
  }) {
    return MemberLocationModel(
      memberId: memberId ?? this.memberId,

      userId: userId ?? this.userId,

      name: name ?? this.name,

      latitude: latitude ?? this.latitude,

      longitude: longitude ?? this.longitude,

      accuracy: accuracy ?? this.accuracy,

      capturedAt: capturedAt ?? this.capturedAt,

      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
