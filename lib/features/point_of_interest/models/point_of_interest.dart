class PointOfInterest {
  final int id;
  final String name;
  final String? description;
  final double radius;
  final double latitude;
  final double longitude;
  final int groupId;
  final DateTime createdAt;

  const PointOfInterest({
    required this.id,
    required this.name,
    this.description,
    required this.radius,
    required this.latitude,
    required this.longitude,
    required this.groupId,
    required this.createdAt,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      radius: (json['radius'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      groupId: json['groupId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
