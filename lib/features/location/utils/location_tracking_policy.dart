import '../models/location_permission_status.dart';
import '../models/location_sharing_model.dart';

bool shouldRunLocationTracking(
  List<LocationSharingModel> sharing,
  LocationPermissionStatus permission,
) {
  return permission == LocationPermissionStatus.always &&
      sharing.any((item) => item.effectiveLocationSharing);
}
