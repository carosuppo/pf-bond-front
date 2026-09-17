import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/routes/app_routes.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/core/theme/app_colors.dart';
import 'package:bond_front/features/auth/models/auth_response.dart';
import 'package:bond_front/features/auth/models/user_model.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:bond_front/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Storage extends SessionStorageService {
  _Storage(this.events);
  final List<String> events;
  bool hasToken = true;
  bool hasExpiration = true;
  bool failClear = false;

  @override
  Future<void> clearSession() async {
    events.add('clear-session');
    if (failClear) throw Exception('secure storage');
    hasToken = false;
    hasExpiration = false;
  }
}

class _Preferences extends AppPreferencesService {
  _Preferences(this.events);
  final List<String> events;
  bool failClear = false;

  @override
  Future<void> clearActiveGroupId() async {
    events.add('clear-preferences');
    if (failClear) throw Exception('preferences');
  }
}

class _Api extends ApiClient {
  _Api(super.sessionStorage, this.events);
  final List<String> events;
  Future<void> Function()? onDelete;

  @override
  Future<void> authenticatedDelete(String path) async {
    events.add('DELETE $path');
    await onDelete?.call();
  }

  @override
  Future<void> authenticatedPostNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async => events.add('logout');
}

class _Push extends PushNotificationService {
  _Push(_Api api, this.events)
    : super(NotificationApiService(api), AppPreferencesService());
  final List<String> events;

  @override
  void onLoggedOut() => events.add('push-local-cleanup');

  @override
  Future<void> unregisterCurrentDevice() async => events.add('push-http');
}

class _Background extends BackgroundLocationService {
  _Background(this.events);
  final List<String> events;
  bool failStop = false;

  @override
  Future<void> stop() async {
    events.add('stop-location');
    if (failStop) throw Exception('tracking');
  }
}

class _Cleanup implements SessionStateCleanup {
  _Cleanup(
    this.events,
    this.storage,
    this.push,
    this.preferences,
    this.background,
  );
  final List<String> events;
  final _Storage storage;
  final _Push push;
  final _Preferences preferences;
  final _Background background;

  @override
  Future<void> clear() async {
    try {
      await storage.clearSession();
    } catch (error) {
      debugPrint('Error de storage simulado: $error');
    }
    push.onLoggedOut();
    try {
      await preferences.clearActiveGroupId();
    } catch (error) {
      debugPrint('Error de preferencias simulado: $error');
    }
    try {
      await background.stop();
    } catch (error) {
      debugPrint('Error de tracking simulado: $error');
    }
    events.add('clear-session-state');
  }
}

class _Fixture {
  _Fixture() {
    // All collaborators share one event log for ordering assertions.
    storage = _Storage(events);
    api = _Api(storage, events);
    preferences = _Preferences(events);
    push = _Push(api, events);
    background = _Background(events);
    provider = AuthProvider(
      AuthService(api, storage, push, background),
      _Cleanup(events, storage, push, preferences, background),
    );
    provider.authResponse = AuthResponse(
      sessionToken: 'session',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      user: UserModel(
        id: 7,
        name: 'Persona',
        email: 'persona@bond.test',
        locationId: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  late final _Storage storage;
  final List<String> events = [];
  late final _Api api;
  late final _Push push;
  late final _Preferences preferences;
  late final _Background background;
  late final AuthProvider provider;
}

Future<void> _showSettings(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: fixture.provider,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Abrir configuracion'),
            ),
          ),
        ),
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login de prueba')),
        },
      ),
    ),
  );
  await tester.tap(find.text('Abrir configuracion'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la opcion destructiva confirma y cancelar no altera nada', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _showSettings(tester, fixture);
    final option = find.text('Eliminar cuenta');
    expect(option, findsOneWidget);
    final text = tester.widget<Text>(option);
    expect(text.style?.color, AppColors.error);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.textContaining('irreversible'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.events, isEmpty);
    expect(fixture.provider.authResponse, isNotNull);
    expect(fixture.storage.hasToken, isTrue);
  });

  testWidgets('error conserva sesion y configuracion', (tester) async {
    final fixture = _Fixture();
    fixture.api.onDelete = () async => throw Exception('Fallo del servidor');
    await _showSettings(tester, fixture);
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar cuenta').last);
    await tester.pumpAndSettle();

    expect(fixture.events, ['DELETE /user/me']);
    expect(fixture.storage.hasToken, isTrue);
    expect(fixture.storage.hasExpiration, isTrue);
    expect(fixture.provider.authResponse, isNotNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.textContaining('Fallo del servidor'), findsOneWidget);
  });

  testWidgets('exito limpia datos locales y toda la navegacion autenticada', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _showSettings(tester, fixture);
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar cuenta').last);
    await tester.pumpAndSettle();

    expect(fixture.events, [
      'DELETE /user/me',
      'clear-session',
      'push-local-cleanup',
      'clear-preferences',
      'stop-location',
      'clear-session-state',
    ]);
    expect(fixture.storage.hasToken, isFalse);
    expect(fixture.storage.hasExpiration, isFalse);
    expect(fixture.provider.authResponse, isNull);
    expect(find.text('Login de prueba'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    final context = tester.element(find.text('Login de prueba'));
    expect(Navigator.of(context).canPop(), isFalse);
  });

  test(
    'solo envia una solicitud mientras la eliminacion esta pendiente',
    () async {
      final fixture = _Fixture();
      final blocker = Completer<void>();
      fixture.api.onDelete = () => blocker.future;
      final first = fixture.provider.deleteAccount();
      final second = await fixture.provider.deleteAccount();
      expect(second, isFalse);
      expect(fixture.provider.isDeletingAccount, isTrue);
      expect(fixture.events, ['DELETE /user/me']);
      blocker.complete();
      expect(await first, isTrue);
    },
  );

  for (final failedStep in ['storage', 'preferences', 'tracking']) {
    testWidgets('navega a login tras 204 aunque falle $failedStep', (
      tester,
    ) async {
      final fixture = _Fixture();
      fixture.storage.failClear = failedStep == 'storage';
      fixture.preferences.failClear = failedStep == 'preferences';
      fixture.background.failStop = failedStep == 'tracking';
      await _showSettings(tester, fixture);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar cuenta').last);
      await tester.pumpAndSettle();

      expect(fixture.provider.authResponse, isNull);
      expect(fixture.provider.errorMessage, isNull);
      expect(fixture.events, contains('push-local-cleanup'));
      expect(fixture.events, contains('clear-session-state'));
      expect(find.text('Login de prueba'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.textContaining('No se pudo eliminar'), findsNothing);
      expect(
        Navigator.of(tester.element(find.text('Login de prueba'))).canPop(),
        isFalse,
      );
    });
  }
}
