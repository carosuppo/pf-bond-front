import 'point_of_interest_color.dart';

enum PointOfInterestValidity {
  permanent('PERMANENT', 'Permanente'),
  twelveHours('TWELVE_HOURS', '12 horas'),
  oneDay('ONE_DAY', '1 día'),
  threeDays('THREE_DAYS', '3 días');

  final String backendValue;
  final String label;

  const PointOfInterestValidity(this.backendValue, this.label);

  static PointOfInterestValidity fromBackend(Object? value) =>
      values.firstWhere(
        (item) => item.backendValue == value,
        orElse: () => PointOfInterestValidity.permanent,
      );
}

class CreatePointOfInterestRequest {
  final PointOfInterestColor color;
  final String name;
  final double radius;
  final double latitude;
  final double longitude;
  final PointOfInterestValidity validity;

  const CreatePointOfInterestRequest({
    this.color = PointOfInterestColor.blue,
    required this.name,
    required this.radius,
    required this.latitude,
    required this.longitude,
    this.validity = PointOfInterestValidity.permanent,
  });

  Map<String, dynamic> toJson() => {
    'color': color.backendValue,
    'name': name.trim(),
    'radius': radius,
    'latitude': latitude,
    'longitude': longitude,
    'validity': validity.backendValue,
  };
}

class UpdatePointOfInterestRequest {
  final PointOfInterestColor? color;
  final String? name;
  final PointOfInterestValidity? validity;
  final double? radius;
  final double? latitude;
  final double? longitude;

  const UpdatePointOfInterestRequest({
    this.color,
    this.name,
    this.validity,
    this.radius,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    if (color != null) 'color': color!.backendValue,
    if (name != null) 'name': name!.trim(),
    if (validity != null) 'validity': validity!.backendValue,
    if (radius != null) 'radius': radius,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}
