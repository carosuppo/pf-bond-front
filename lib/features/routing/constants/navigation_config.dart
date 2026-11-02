import '../models/route_mode.dart';

class NavigationConfig {
  const NavigationConfig._();

  /// Desviación normal tolerada antes de comenzar a considerar
  /// que el usuario abandonó la ruta.
  static const walkingDeviationMeters = 40.0;
  static const drivingDeviationMeters = 60.0;

  /// Una desviación considerablemente mayor debe provocar un recálculo
  /// inmediato sin esperar varias muestras consecutivas.
  static const walkingSevereDeviationMeters = 80.0;
  static const drivingSevereDeviationMeters = 120.0;

  /// Para desviaciones normales seguimos confirmando con varias muestras
  /// para evitar recalcular por un único salto de GPS.
  static const consecutiveOffRouteReadings = 3;

  /// Después de un recálculo normal no queremos bombardear al proveedor,
  /// pero 20 segundos resultaba demasiado perceptible para navegación.
  static const recalculationCooldown = Duration(seconds: 8);

  /// Una desviación grave puede volver a provocar un recálculo antes.
  static const severeRecalculationCooldown = Duration(seconds: 3);

  static double deviationThreshold(RouteMode mode) {
    return mode == RouteMode.walking
        ? walkingDeviationMeters
        : drivingDeviationMeters;
  }

  static double severeDeviationThreshold(RouteMode mode) {
    return mode == RouteMode.walking
        ? walkingSevereDeviationMeters
        : drivingSevereDeviationMeters;
  }
}
