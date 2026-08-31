import '../../../core/network/api_client.dart';
import '../models/event_model.response.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  Future<List<EventResponseModel>> getEvents({required int groupId}) async {
    final response = await _apiClient.authenticatedGetList(
      '/group/$groupId/event',
    );
    return response.map(EventResponseModel.fromJson).toList(growable: false);
  }

  Future<EventResponseModel> getEventById({
    required int groupId,
    required int eventId,
  }) async {
    final response = await _apiClient.authenticatedGet(
      '/group/$groupId/event/$eventId',
    );
    return EventResponseModel.fromJson(response);
  }
}
