import 'package:geolocator/geolocator.dart';

import '../constants/location_tracking_config.dart';
import '../mappers/location_mapper.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';

class LocationService {
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
    return mapPosition(await Geolocator.getCurrentPosition());
  }

  Stream<LocationModel> getLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LocationTrackingConfig.distanceFilterMeters,
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
