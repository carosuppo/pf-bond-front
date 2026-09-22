import '../models/route_mode.dart';

class NavigationConfig {
  static const walkingDeviationMeters = 40.0;
  static const drivingDeviationMeters = 60.0;
  static const consecutiveOffRouteReadings = 3;
  static const recalculationCooldown = Duration(seconds: 20);

  static double deviationThreshold(RouteMode mode) => mode == RouteMode.walking
      ? walkingDeviationMeters
      : drivingDeviationMeters;
}
