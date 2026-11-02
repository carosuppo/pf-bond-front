import 'point_of_interest_color.dart';
import 'point_of_interest_request.dart';

class PointOfInterest {
  final PointOfInterestColor color;
  final int id;
  final String name;
  final double radius;
  final double latitude;
  final double longitude;
  final int groupId;
  final DateTime createdAt;
  final PointOfInterestValidity validity;
  final DateTime? endTime;

  const PointOfInterest({
    this.color = PointOfInterestColor.blue,
    required this.id,
    required this.name,
    required this.radius,
    required this.latitude,
    required this.longitude,
    required this.groupId,
    required this.createdAt,
    this.validity = PointOfInterestValidity.permanent,
    this.endTime,
  });

  bool isActiveAt(DateTime moment) =>
      validity == PointOfInterestValidity.permanent ||
      (endTime?.isAfter(moment.toUtc()) ?? false);

  bool get isTemporary => validity != PointOfInterestValidity.permanent;

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      color: json.containsKey('color')
          ? PointOfInterestColor.fromBackend(json['color'])
          : PointOfInterestColor.blue,
      id: json['id'] as int,
      name: json['name'] as String,
      radius: (json['radius'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      groupId: json['groupId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      validity: PointOfInterestValidity.fromBackend(json['validity']),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String).toUtc(),
    );
  }
}
