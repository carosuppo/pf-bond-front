import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class RouteProgress {
  const RouteProgress({
    required this.remainingPoints,
    required this.remainingDistanceMeters,
    required this.distanceToRouteMeters,
    required this.progressMeters,
  });

  final List<LatLng> remainingPoints;
  final double remainingDistanceMeters;
  final double distanceToRouteMeters;
  final double progressMeters;
}

class RouteProgressTracker {
  RouteProgressTracker(List<LatLng> points)
    : assert(points.length >= 2),
      _points = List.unmodifiable(points) {
    _cumulativeMeters = List<double>.filled(_points.length, 0);

    for (var index = 1; index < _points.length; index++) {
      _cumulativeMeters[index] =
          _cumulativeMeters[index - 1] +
          distanceMeters(_points[index - 1], _points[index]);
    }
  }

  static const _earthRadiusMeters = 6371000.0;

  /// El tracker no puede saltar arbitrariamente hacia cualquier punto
  /// futuro de una ruta larga o que se cruza consigo misma.
  static const maxForwardSearchMeters = 500.0;

  static const _backwardSearchSegments = 2;

  /// Valor por defecto para consumidores que no especifiquen uno.
  ///
  /// NavigationProvider suministra dinámicamente un valor basado en
  /// modo de viaje + accuracy GPS.
  static const maxProgressSnapDistanceMeters = 60.0;

  final List<LatLng> _points;

  late final List<double> _cumulativeMeters;

  double _progressMeters = 0;

  int _segmentIndex = 0;

  double get totalDistanceMeters => _cumulativeMeters.last;

  RouteProgress update(
    LatLng location, {
    double maxSnapDistanceMeters = maxProgressSnapDistanceMeters,
  }) {
    assert(maxSnapDistanceMeters >= 0);

    var bestDistance = double.infinity;
    var bestProgress = _progressMeters;

    final maximumProgress = math.min(
      totalDistanceMeters,
      _progressMeters + maxForwardSearchMeters,
    );

    for (
      var index = math.max(0, _segmentIndex - _backwardSearchSegments);
      index < _points.length - 1;
      index++
    ) {
      if (_cumulativeMeters[index] > maximumProgress) {
        break;
      }

      final projection = _project(location, _points[index], _points[index + 1]);

      final segmentLength =
          _cumulativeMeters[index + 1] - _cumulativeMeters[index];

      final projectedProgress =
          _cumulativeMeters[index] + segmentLength * projection.fraction;

      final projectionIsAheadOfWindow = projectedProgress > maximumProgress;

      final candidateProgress =
          projectedProgress < _progressMeters || projectionIsAheadOfWindow
          ? _progressMeters
          : projectedProgress;

      final candidateDistance = projectionIsAheadOfWindow
          ? distanceMeters(location, _pointAtProgress(index, maximumProgress))
          : projection.distanceMeters;

      if (candidateDistance < bestDistance) {
        bestDistance = candidateDistance;
        bestProgress = candidateProgress;
      }
    }

    /*
     * Que exista un segmento "más cercano" no significa que el usuario
     * esté suficientemente cerca como para considerarlo parte de la ruta.
     *
     * Si estamos demasiado lejos:
     *
     * - NO adelantamos _progressMeters;
     * - NO escondemos parte de la ruta;
     * - sí devolvemos distanceToRouteMeters;
     *
     * NavigationProvider utilizará esa distancia para decidir si debe
     * recalcular.
     */
    if (bestDistance <= maxSnapDistanceMeters) {
      _progressMeters = math.max(_progressMeters, bestProgress);
    }

    while (_segmentIndex < _points.length - 2 &&
        _cumulativeMeters[_segmentIndex + 1] <= _progressMeters) {
      _segmentIndex++;
    }

    final segmentStart = _cumulativeMeters[_segmentIndex];

    final segmentEnd = _cumulativeMeters[_segmentIndex + 1];

    final segmentFraction = segmentEnd == segmentStart
        ? 1.0
        : ((_progressMeters - segmentStart) / (segmentEnd - segmentStart))
              .clamp(0.0, 1.0);

    final projectedPoint = _interpolate(
      _points[_segmentIndex],
      _points[_segmentIndex + 1],
      segmentFraction,
    );

    return RouteProgress(
      remainingPoints: [projectedPoint, ..._points.skip(_segmentIndex + 1)],
      remainingDistanceMeters: math.max(
        0,
        totalDistanceMeters - _progressMeters,
      ),
      distanceToRouteMeters: bestDistance,
      progressMeters: _progressMeters,
    );
  }

  static double distanceMeters(LatLng first, LatLng second) {
    final latitudeDelta = _radians(second.latitude - first.latitude);

    final longitudeDelta = _radians(second.longitude - first.longitude);

    final firstLatitude = _radians(first.latitude);
    final secondLatitude = _radians(second.latitude);

    final value =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(firstLatitude) *
            math.cos(secondLatitude) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);

    final normalizedValue = value.clamp(0.0, 1.0);

    return _earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(normalizedValue), math.sqrt(1 - normalizedValue));
  }

  _Projection _project(LatLng point, LatLng start, LatLng end) {
    final referenceLatitude = _radians(
      (point.latitude + start.latitude + end.latitude) / 3,
    );

    final pointXY = _toMeters(point, referenceLatitude);

    final startXY = _toMeters(start, referenceLatitude);

    final endXY = _toMeters(end, referenceLatitude);

    final dx = endXY.$1 - startXY.$1;
    final dy = endXY.$2 - startXY.$2;

    final lengthSquared = dx * dx + dy * dy;

    final fraction = lengthSquared == 0
        ? 0.0
        : (((pointXY.$1 - startXY.$1) * dx + (pointXY.$2 - startXY.$2) * dy) /
                  lengthSquared)
              .clamp(0.0, 1.0);

    final projectedX = startXY.$1 + dx * fraction;

    final projectedY = startXY.$2 + dy * fraction;

    return _Projection(
      fraction: fraction,
      distanceMeters: math.sqrt(
        math.pow(pointXY.$1 - projectedX, 2) +
            math.pow(pointXY.$2 - projectedY, 2),
      ),
    );
  }

  static (double, double) _toMeters(LatLng point, double referenceLatitude) => (
    _earthRadiusMeters *
        _radians(point.longitude) *
        math.cos(referenceLatitude),
    _earthRadiusMeters * _radians(point.latitude),
  );

  static LatLng _interpolate(LatLng start, LatLng end, double fraction) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
  }

  LatLng _pointAtProgress(int segmentIndex, double progressMeters) {
    final segmentStart = _cumulativeMeters[segmentIndex];

    final segmentEnd = _cumulativeMeters[segmentIndex + 1];

    final fraction = segmentEnd == segmentStart
        ? 1.0
        : ((progressMeters - segmentStart) / (segmentEnd - segmentStart)).clamp(
            0.0,
            1.0,
          );

    return _interpolate(
      _points[segmentIndex],
      _points[segmentIndex + 1],
      fraction,
    );
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class _Projection {
  const _Projection({required this.fraction, required this.distanceMeters});

  final double fraction;

  final double distanceMeters;
}
