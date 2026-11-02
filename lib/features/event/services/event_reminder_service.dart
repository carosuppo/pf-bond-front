import '../../../core/network/api_client.dart';
import '../models/event_reminder_model.response.dart';

class EventReminderService {
  final ApiClient _apiClient;

  EventReminderService(this._apiClient);

  Future<List<EventReminderModel>> getReminders({
    required int groupId,
    required int eventId,
  }) async {
    final response = await _apiClient.authenticatedGetList(
      '/group/$groupId/event/$eventId/reminders',
    );
    return response.map(EventReminderModel.fromJson).toList(growable: false);
  }

  Future<List<EventReminderModel>> setReminders({
    required int groupId,
    required int eventId,
    required List<int> leadMinutes,
    int? utcOffsetMinutes,
  }) async {
    final offset = utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    final response = await _apiClient.authenticatedPut(
      '/group/$groupId/event/$eventId/reminders',
      {
        'reminders': [
          for (final lead in leadMinutes)
            {'leadMinutes': lead, 'utcOffsetMinutes': offset},
        ],
      },
    );
    final items = response['reminders'] as List;
    return items
        .map(
          (item) => EventReminderModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> deleteReminders({
    required int groupId,
    required int eventId,
  }) async {
    await _apiClient.authenticatedDelete(
      '/group/$groupId/event/$eventId/reminders',
    );
  }
}
