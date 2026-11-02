import '../../../core/network/api_client.dart';
import '../models/create_event_model.request.dart';
import '../models/event_model.response.dart';
import '../models/update_event_model.request.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  Future<List<EventResponseModel>> getEvents({
    required int groupId,
    required int year,
    int? month,
  }) async {
    final query = month == null ? '?year=$year' : '?year=$year&month=$month';
    final response = await _apiClient.authenticatedGetList(
      '/group/$groupId/event$query',
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

  Future<EventResponseModel> createEvent({
    required int groupId,
    required CreateEventRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group/$groupId/event',
      request.toJson(),
    );
    return EventResponseModel.fromJson(response);
  }

  Future<EventResponseModel> updateEvent({
    required int groupId,
    required int eventId,
    required UpdateEventRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPatch(
      '/group/$groupId/event/$eventId',
      request.toJson(),
    );

    return EventResponseModel.fromJson(response);
  }

  Future<void> cancelEvent({required int groupId, required int eventId}) async {
    await _apiClient.authenticatedDelete('/group/$groupId/event/$eventId');
  }

  Future<EventResponseModel> setEventLocation({
    required int groupId,
    required int eventId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.authenticatedPatch(
      '/group/$groupId/event/$eventId/location',
      {'latitude': latitude, 'longitude': longitude},
    );

    return EventResponseModel.fromJson(response);
  }
}
