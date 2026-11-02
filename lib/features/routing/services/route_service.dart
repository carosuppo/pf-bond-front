import '../../../core/network/api_client.dart';
import '../../location/models/location_model.dart';
import '../models/route_mode.dart';
import '../models/route_response.dart';

class RouteService {
  RouteService(this._apiClient);

  final ApiClient _apiClient;

  Future<RouteResponse> calculate({
    required int groupId,
    required int pointId,
    required LocationModel origin,
    required RouteMode mode,
  }) async {
    final response = await _apiClient
        .authenticatedPost('/group/$groupId/point-of-interest/$pointId/route', {
          'originLatitude': origin.latitude,
          'originLongitude': origin.longitude,
          'mode': mode.backendValue,
        });
    return RouteResponse.fromJson(response);
  }
}
