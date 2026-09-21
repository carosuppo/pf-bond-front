import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionStorage extends SessionStorageService {
  _FakeSessionStorage(this.events);
  final List<String> events;

  @override
  Future<void> clearSession() async => events.add('clear-session');
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.sessionStorage, this.events);
  final List<String> events;

  @override
  Future<void> authenticatedPostNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async => events.add('backend-logout');
}

class _FakePushService extends PushNotificationService {
  _FakePushService(ApiClient client, this.events)
    : super(NotificationApiService(client), AppPreferencesService());
  final List<String> events;

  @override
  Future<void> unregisterCurrentDevice() async => events.add('unregister-fcm');

  @override
  void onLoggedOut() => events.add('push-logged-out');
}

class _FakeBackgroundLocationService extends BackgroundLocationService {
  _FakeBackgroundLocationService(this.events);
  final List<String> events;

  @override
  Future<void> stop() async => events.add('stop-tracking');
}

void main() {
  test('logout stops tracking before clearing the session', () async {
    final events = <String>[];
    final storage = _FakeSessionStorage(events);
    final api = _FakeApiClient(storage, events);
    final service = AuthService(
      api,
      storage,
      _FakePushService(api, events),
      _FakeBackgroundLocationService(events),
    );

    await service.logout();

    expect(events, <String>[
      'stop-tracking',
      'unregister-fcm',
      'backend-logout',
    ]);
  });
}
