import 'package:bond_front/features/routing/utils/route_progress_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('oculta lo recorrido y el progreso no retrocede por ruido GPS', () {
    final tracker = RouteProgressTracker(const [
      LatLng(0, 0),
      LatLng(0, 0.005),
      LatLng(0, 0.01),
    ]);

    tracker.update(const LatLng(0, 0.004));
    final advanced = tracker.update(const LatLng(0, 0.006));
    final noisyBackward = tracker.update(const LatLng(0, 0.004));

    expect(advanced.progressMeters, greaterThan(600));
    expect(noisyBackward.progressMeters, advanced.progressMeters);
    expect(
      noisyBackward.remainingDistanceMeters,
      advanced.remainingDistanceMeters,
    );
    expect(
      noisyBackward.remainingPoints.first.longitude,
      closeTo(0.006, 0.0001),
    );
  });

  test('proyecta sobre el segmento y mide distancia transversal', () {
    final tracker = RouteProgressTracker(const [LatLng(0, 0), LatLng(0, 0.01)]);
    final progress = tracker.update(const LatLng(0.001, 0.004));

    expect(progress.progressMeters, closeTo(445, 5));
    expect(progress.distanceToRouteMeters, closeTo(111, 5));
    expect(progress.remainingPoints.first.latitude, closeTo(0, 0.00001));
  });

  test('no salta a un tramo lejano que cruza cerca de la posición actual', () {
    final tracker = RouteProgressTracker(const [
      LatLng(0, 0),
      LatLng(0, 0.001),
      LatLng(0.001, 0.001),
      LatLng(0.001, -0.001),
      LatLng(-0.001, -0.001),
      LatLng(-0.001, 0.0005),
      LatLng(0.001, 0.0005),
      LatLng(0.001, 0.002),
    ]);

    final progress = tracker.update(const LatLng(0.00002, 0.0005));

    expect(progress.progressMeters, lessThan(100));
    expect(progress.distanceToRouteMeters, lessThan(3));
    expect(progress.remainingPoints.first.longitude, closeTo(0.0005, 0.0001));
  });

  test('limita por distancia el avance incluso con geometría poco densa', () {
    final tracker = RouteProgressTracker(const [LatLng(0, 0), LatLng(0, 0.02)]);

    final distantReading = tracker.update(const LatLng(0, 0.01));
    final localReading = tracker.update(const LatLng(0, 0.004));

    expect(distantReading.progressMeters, 0);
    expect(
      localReading.progressMeters,
      lessThanOrEqualTo(RouteProgressTracker.maxForwardSearchMeters),
    );
    expect(localReading.progressMeters, closeTo(445, 5));
  });
}
