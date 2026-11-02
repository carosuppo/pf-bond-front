import '../../location/models/location_socket_event.dart';

Future<void> refreshPointsForSocketEvent({
  required LocationSocketEvent event,
  required int? viewingGroupId,
  required Future<void> Function(int groupId) loadPoints,
}) async {
  if (event is! PointOfInterestSocketEvent || event.groupId != viewingGroupId) {
    return;
  }

  await loadPoints(event.groupId);
}
