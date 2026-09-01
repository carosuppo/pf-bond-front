class CreatePointOfInterestRequest {
  final String name;
  final String? description;
  final double radius;
  final double latitude;
  final double longitude;

  const CreatePointOfInterestRequest({
    required this.name,
    this.description,
    required this.radius,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': _normalizedDescription(description),
    'radius': radius,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class UpdatePointOfInterestRequest {
  final String? name;
  final String? description;
  final double? radius;
  final double? latitude;
  final double? longitude;

  const UpdatePointOfInterestRequest({
    this.name,
    this.description,
    this.radius,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
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
