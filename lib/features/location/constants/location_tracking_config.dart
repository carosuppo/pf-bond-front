class LocationTrackingConfig {
  const LocationTrackingConfig._();

  static const int distanceFilterMeters = 25;

  static const Duration minimumPublishInterval =
      Duration(seconds: 15);

  static const double minimumPublishDistanceMeters = 5;

  static const Duration reconnectDelay =
      Duration(seconds: 5);

  static const Duration heartbeatInterval =
      Duration(minutes: 1);

  static const Duration staleAfter =
      Duration(minutes: 3);

  static const Duration hideAfter =
      Duration(minutes: 10);

  static const Duration freshnessRefreshInterval =
      Duration(seconds: 30);
}
