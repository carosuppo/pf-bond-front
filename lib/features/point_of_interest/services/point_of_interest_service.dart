import '../../../core/network/api_client.dart';
import '../models/point_of_interest.dart';
import '../models/point_of_interest_request.dart';

class PointOfInterestService {
  final ApiClient _apiClient;

  PointOfInterestService(this._apiClient);

  String _basePath(int groupId) => '/group/$groupId/point-of-interest';

  Future<List<PointOfInterest>> getAll(int groupId) async {
    final response = await _apiClient.authenticatedGetList(_basePath(groupId));
    return response.map(PointOfInterest.fromJson).toList(growable: false);
  }

  Future<PointOfInterest> create(
    int groupId,
    CreatePointOfInterestRequest request,
  ) async {
    final response = await _apiClient.authenticatedPost(
      _basePath(groupId),
      request.toJson(),
    );
    return PointOfInterest.fromJson(response);
  }

  Future<PointOfInterest> update(
    int groupId,
    int pointId,
    UpdatePointOfInterestRequest request,
  ) async {
    final response = await _apiClient.authenticatedPatch(
      '${_basePath(groupId)}/$pointId',
      request.toJson(),
    );
    return PointOfInterest.fromJson(response);
  }

  Future<void> delete(int groupId, int pointId) {
    return _apiClient.authenticatedDelete('${_basePath(groupId)}/$pointId');
  }
}
