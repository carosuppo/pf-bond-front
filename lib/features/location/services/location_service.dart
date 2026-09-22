import 'package:geolocator/geolocator.dart';

import '../mappers/location_mapper.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';

class LocationService {
  /// Durante navegación necesitamos actualizaciones mucho más frecuentes que
  /// las utilizadas originalmente.
  ///
  /// El tracking en segundo plano para compartir ubicación utiliza
  /// BackgroundLocationService, por lo que bajar este filtro no provoca que
  /// Bond publique la ubicación del usuario al backend cada 5 metros.
  static const int _navigationDistanceFilterMeters = 5;

  Future<LocationPermissionStatus> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }

    return mapPermission(await Geolocator.checkPermission());
  }

  Future<LocationPermissionStatus> requestBackgroundPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return mapPermission(permission);
  }

  Future<LocationPermissionStatus> requestForegroundPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return mapPermission(permission);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<LocationModel> getCurrentLocation() async {
    return mapPosition(
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      ),
    );
  }

  Stream<LocationModel> getLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _navigationDistanceFilterMeters,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map(mapPosition);
  }

  double distanceBetween(LocationModel first, LocationModel second) {
    return Geolocator.distanceBetween(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }
}
