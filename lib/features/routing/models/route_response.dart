import 'package:latlong2/latlong.dart';

class RouteResponse {
  const RouteResponse({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    if (rawPoints is! List) {
      throw const FormatException('La ruta no contiene una geometría válida.');
    }

    final points = rawPoints
        .map((rawPoint) {
          if (rawPoint is! Map) {
            throw const FormatException(
              'La ruta contiene coordenadas inválidas.',
            );
          }
          final point = Map<String, dynamic>.from(rawPoint);
          return LatLng(
            (point['latitude'] as num).toDouble(),
            (point['longitude'] as num).toDouble(),
          );
        })
        .toList(growable: false);

    if (points.length < 2) {
      throw const FormatException('No se encontró un camino hasta el destino.');
    }

    return RouteResponse(
      points: points,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
    );
  }
}
