import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';
import '../models/location_permission_status.dart';

LocationModel mapPosition(Position position) {
  return LocationModel(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    timestamp: position.timestamp,
  );
}

LocationPermissionStatus mapPermission(LocationPermission permission) {
  switch (permission) {
    case LocationPermission.always:
    case LocationPermission.whileInUse:
      return LocationPermissionStatus.granted;

    case LocationPermission.denied:
      return LocationPermissionStatus.denied;

    case LocationPermission.deniedForever:
      return LocationPermissionStatus.deniedForever;

    case LocationPermission.unableToDetermine:
      return LocationPermissionStatus.denied;
  }
}
