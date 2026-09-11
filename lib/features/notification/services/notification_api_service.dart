import '../models/notification_preferences.dart';
import '../../../core/network/api_client.dart';

class NotificationApiService {
  final ApiClient _apiClient;

  NotificationApiService(this._apiClient);

  Future<NotificationPreferences> getPreferences() async =>
      NotificationPreferences.fromJson(
        await _apiClient.authenticatedGet('/notification/preferences'),
      );
  Future<void> setGlobalPreference(bool enabled) async {
    await _apiClient.authenticatedPatch('/notification/preferences/global', {
      'enabled': enabled,
    });
  }

  Future<void> setGroupPreference(int groupId, bool enabled) async {
    await _apiClient.authenticatedPatch(
      '/notification/preferences/group/$groupId',
      {'enabled': enabled},
    );
  }

  Future<void> setTypePreference(int groupId, String type, bool enabled) async {
    await _apiClient.authenticatedPatch(
      '/notification/preferences/group/$groupId/type',
      {'type': type, 'enabled': enabled},
    );
  }

  Future<void> registerDeviceToken(String token) {
    return _apiClient.authenticatedPostNoContent(
      '/notification/device-token',
      body: {'token': token, 'platform': 'android'},
    );
  }

  Future<void> unregisterDeviceToken(String token) {
    return _apiClient.authenticatedPostNoContent(
      '/notification/device-token/unregister',
      body: {'token': token},
    );
  }
}
