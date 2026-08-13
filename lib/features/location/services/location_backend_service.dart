import '../../../core/network/api_client.dart';
import '../models/location_model.dart';
import '../models/location_sharing_model.dart';
import '../models/member_location_model.dart';

class LocationBackendService {
  final ApiClient _apiClient;

  LocationBackendService(this._apiClient);

  Future<List<LocationSharingModel>> getSharing() async {
    final response = await _apiClient.authenticatedGetList('/location/sharing');
    return response.map(LocationSharingModel.fromJson).toList(growable: false);
  }

  Future<LocationSharingModel> updateGroupSharing(
    int groupId,
    bool enabled,
  ) async {
    final response = await _apiClient.authenticatedPut(
      '/location/group/$groupId/sharing',
      <String, dynamic>{'enabled': enabled},
    );
    return LocationSharingModel.fromJson(response);
  }

  Future<List<MemberLocationModel>> getGroupMembers(int groupId) async {
    final response = await _apiClient.authenticatedGetList(
      '/location/group/$groupId/members',
    );
    return response.map(MemberLocationModel.fromJson).toList(growable: false);
  }

  Future<void> publishCurrentLocation(LocationModel location) async {
    await _apiClient.authenticatedPut('/location/current', <String, dynamic>{
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
      'capturedAt': location.timestamp.toUtc().toIso8601String(),
    });
  }
}
