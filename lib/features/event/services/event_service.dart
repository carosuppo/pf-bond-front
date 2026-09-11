import '../../../core/network/api_client.dart';
import '../models/create_event_model.request.dart';
import '../models/create_event_model.response.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  Future<List<CreateEventResponseModel>> getEvents({
    required int groupId,
  }) async {
    final response = await _apiClient.authenticatedGetList(
      '/group/$groupId/event',
    );
    return response
        .map(CreateEventResponseModel.fromJson)
        .toList(growable: false);
  }

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
