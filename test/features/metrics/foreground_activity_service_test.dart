import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/models/auth_response.dart';
import 'package:bond_front/features/auth/models/login_request.dart';
import 'package:bond_front/features/auth/models/user_model.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/metrics/services/foreground_activity_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ApiClient {
  _Api() : super(SessionStorageService());
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  Future<void> authenticatedPostNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    expectSync(path, '/user/activity');
    expectSync(body, isNull);
    calls++;
    if (fail) throw Exception('offline');
    await pending?.future;
  }
}

class _AuthService extends AuthService {
  _AuthService(ApiClient api, this.session)
    : super(
        api,
        SessionStorageService(),
        PushNotificationService(
          NotificationApiService(api),
          AppPreferencesService(),
        ),
        BackgroundLocationService(),
      );
  AuthResponse? session;
  @override
  Future<AuthResponse> login(LoginRequest request) async => session!;
  @override
  Future<AuthResponse?> restoreSession() async => session;
  @override
  Future<void> logout() async {}
}

class _Cleanup implements SessionStateCleanup {
  @override
  Future<void> clear() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late _Api api;
  late _AuthService authService;
  late AuthProvider auth;
  late ForegroundActivityService activity;

  setUp(() {
    now = DateTime.utc(2026, 10, 15);
    api = _Api();
    authService = _AuthService(
      api,
      AuthResponse(
        sessionToken: 'test-session',
        expiresAt: now.add(const Duration(days: 30)),
        user: UserModel(
          id: 1,
          name: 'test',
          email: 'test@example.test',
          locationId: null,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    auth = AuthProvider(authService, _Cleanup());
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    activity = ForegroundActivityService(auth, api, now: () => now);
  });
  tearDown(() {
    activity.dispose();
    auth.dispose();
  });

  testWidgets(
    'restoring a valid session counts a read-only user and repeats every five minutes',
    (tester) async {
      expect(api.calls, 0);
      await auth.restoreSession();
      await tester.pump();
      expect(api.calls, 1);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(api.calls, 2);
      activity.dispose();
    },
  );

  testWidgets(
    'login while already resumed records once despite auth notifications',
    (tester) async {
      await auth.login(email: 'test@example.test', password: 'unused');
      auth.updateUser(auth.authResponse!.user);
      await tester.pump();
      expect(api.calls, 1);
      activity.dispose();
    },
  );

  testWidgets(
    'background restoration and background time do not count; resuming does',
    (tester) async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await auth.restoreSession();
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(api.calls, 0);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.calls, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(api.calls, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.calls, 2);
      activity.dispose();
    },
  );

  testWidgets(
    'short resume cycles and unrelated auth notifications do not duplicate signals',
    (tester) async {
      await auth.restoreSession();
      await tester.pump();
      for (int i = 0; i < 3; i++) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        auth.updateUser(auth.authResponse!.user);
      }
      await tester.pump();
      expect(api.calls, 1);
      activity.dispose();
    },
  );

  testWidgets('logout stops all updates', (tester) async {
    await auth.restoreSession();
    await tester.pump();
    await auth.logout();
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.calls, 1);
  });

  testWidgets(
    'failures never affect auth and retry only on the foreground interval',
    (tester) async {
      api.fail = true;
      expect(await auth.restoreSession(), isTrue);
      await tester.pump();
      expect(auth.errorMessage, isNull);
      expect(api.calls, 1);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(api.calls, 2);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(api.calls, 2);
    },
  );

  testWidgets(
    'pending signals never overlap and completion after logout does not restart the timer',
    (tester) async {
      api.pending = Completer<void>();
      await auth.restoreSession();
      now = now.add(const Duration(minutes: 10));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 10));
      expect(api.calls, 1);
      await auth.logout();
      api.pending!.complete();
      await tester.pump();
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(api.calls, 1);
    },
  );

  testWidgets('missing sessions never record activity', (tester) async {
    authService.session = null;
    expect(await auth.restoreSession(), isFalse);
    await tester.pump();
    expect(api.calls, 0);
  });

  testWidgets('expired sessions stop periodic signals', (tester) async {
    await auth.restoreSession();
    await tester.pump();
    now = now.add(const Duration(days: 31));
    await tester.pump(const Duration(minutes: 5));
    expect(api.calls, 1);
  });

  testWidgets('already restored session is recorded when the observer starts', (
    tester,
  ) async {
    activity.dispose();
    await auth.restoreSession();
    expect(api.calls, 0);
    activity = ForegroundActivityService(auth, api, now: () => now);
    await tester.pump();
    expect(api.calls, 1);
    activity.dispose();
  });
}
