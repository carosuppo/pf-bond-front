import '../../../core/network/api_client.dart';

class NotificationApiService {
  final ApiClient _apiClient;

  NotificationApiService(this._apiClient);

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
