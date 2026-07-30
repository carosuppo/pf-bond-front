import 'package:geolocator/geolocator.dart';

import '../mappers/location_mapper.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';

class LocationService {
  Future<LocationPermissionStatus> requestPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return mapPermission(permission);
  }

  Future<LocationModel> getCurrentLocation() async {
    final Position position = await Geolocator.getCurrentPosition();

    return mapPosition(position);
  }

  Stream<LocationModel> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).map(mapPosition);
  }
}
