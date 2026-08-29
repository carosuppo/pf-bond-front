import '../../../core/network/api_client.dart';
import '../models/create_event_model.request.dart';
import '../models/create_event_model.response.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  Future<CreateEventResponseModel> createEvent({
    required int groupId,
    required CreateEventRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group/$groupId/event',
      request.toJson(),
    );
    return CreateEventResponseModel.fromJson(response);
  }
}
