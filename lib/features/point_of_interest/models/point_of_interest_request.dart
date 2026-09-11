import 'point_of_interest_color.dart';

class CreatePointOfInterestRequest {
  final PointOfInterestColor color;
  final String name;
  final String? description;
  final double radius;
  final double latitude;
  final double longitude;

  const CreatePointOfInterestRequest({
    this.color = PointOfInterestColor.blue,
    required this.name,
    this.description,
    required this.radius,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'color': color.backendValue,
    'name': name.trim(),
    'description': _normalizedDescription(description),
    'radius': radius,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class UpdatePointOfInterestRequest {
  final PointOfInterestColor? color;
  final String? name;
  final String? description;
  final double? radius;
  final double? latitude;
  final double? longitude;

  const UpdatePointOfInterestRequest({
    this.color,
    this.name,
    this.description,
    this.radius,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    if (color != null) 'color': color!.backendValue,
    if (name != null) 'name': name!.trim(),
    if (description != null) 'description': _normalizedDescription(description),
    if (radius != null) 'radius': radius,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

String? _normalizedDescription(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
