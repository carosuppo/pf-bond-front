import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/routes/app_router.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/screens/login_screen.dart';
import 'package:bond_front/features/auth/screens/register_screen.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/auth/utils/terms_of_use.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _SessionStorage extends SessionStorageService {
  String? savedSessionToken;
  DateTime? savedExpiresAt;

  @override
  Future<void> saveSession({
    required String sessionToken,
    required DateTime expiresAt,
  }) async {
    savedSessionToken = sessionToken;
    savedExpiresAt = expiresAt;
  }
}

class _ApiClient extends ApiClient {
  _ApiClient(super.sessionStorage);

  final requests = <({String path, Map<String, dynamic> body})>[];
  bool requireAgeVerification = false;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    requests.add((path: path, body: body));
    if (path == '/user/login') {
      if (requireAgeVerification) {
        if (body['birthDate'] == null) {
          throw const ApiException(
            'AGE_VERIFICATION_REQUIRED',
            statusCode: 403,
          );
        }
        if (body['termsVersion'] == null) {
          throw const ApiException(
            'TERMS_ACCEPTANCE_REQUIRED',
            statusCode: 403,
          );
        }
        throw const ApiException(
          'Mail o contraseña incorrectos.',
          statusCode: 401,
        );
      }
      throw const ApiException(
        'Debes verificar tu correo electrónico antes de iniciar sesión.',
        statusCode: 403,
      );
    }
    if (path == '/user/verify-email-session') {
      return {
        'sessionToken': 'verified-session-token',
        'expiresAt': '2027-01-01T00:00:00.000Z',
        'user': {
          'id': 1,
          'name': 'Persona Test',
          'email': 'persona@bond.test',
          'profilePhoto': null,
          'locationId': null,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      };
    }
    return {'message': 'Si el correo existe y no está verificado, se enviará.'};
  }
}

class _PushService extends PushNotificationService {
  _PushService(ApiClient apiClient)
    : super(NotificationApiService(apiClient), AppPreferencesService());

  @override
  Future<void> onAuthenticated() async {}
}

class _SessionStateCleanup implements SessionStateCleanup {
  @override
  Future<void> clear() async {}
}

class _Fixture {
  _Fixture() {
    storage = _SessionStorage();
    apiClient = _ApiClient(storage);
    authProvider = AuthProvider(
      AuthService(
        apiClient,
        storage,
        _PushService(apiClient),
        BackgroundLocationService(),
      ),
      _SessionStateCleanup(),
    );
  }

  late final _SessionStorage storage;
  late final _ApiClient apiClient;
  late final AuthProvider authProvider;
}

void main() {
  testWidgets(
    'valida la repetición de contraseña y abre la verificación al registrarse',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.authProvider.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: ChangeNotifierProvider<AuthProvider>.value(
            value: fixture.authProvider,
            child: MaterialApp(
              home: const RegisterScreen(),
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Necesitás verificar tu correo antes de poder usar la aplicación.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Acepto los'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Persona Test');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'persona@bond.test',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'password124');
      await tester.ensureVisible(find.text('Registrarse'));
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(fixture.apiClient.requests, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.ensureVisible(find.text('Registrarse'));
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aceptá los Términos de uso'), findsOneWidget);
      expect(fixture.apiClient.requests, isEmpty);

      await tester.tap(find.byType(Checkbox).first);
      await tester.ensureVisible(find.text('Registrarse'));
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Ingrese su fecha de nacimiento'), findsOneWidget);

      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final birthDateInput = find.byType(TextField).at(1);
      expect(
        tester.widget<TextField>(birthDateInput).controller?.text,
        MaterialLocalizations.of(
          tester.element(birthDateInput),
        ).formatCompactDate(DateTime.now()),
      );
      await tester.enterText(birthDateInput, '01/01/2000');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta necesita estar verificada'), findsOneWidget);
      expect(find.text('persona@bond.test'), findsOneWidget);
      expect(fixture.apiClient.requests.single.path, '/user');
      expect(
        fixture.apiClient.requests.single.body['birthDate'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
      expect(
        fixture.apiClient.requests.single.body['termsVersion'],
        termsOfUseVersion,
      );
    },
  );

  testWidgets('redirige cuentas sin verificar y permite reenviar el correo', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.authProvider.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: ChangeNotifierProvider<AuthProvider>.value(
          value: fixture.authProvider,
          child: MaterialApp(
            home: const LoginScreen(),
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'persona@bond.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Tu cuenta necesita estar verificada'), findsOneWidget);
    expect(find.text('persona@bond.test'), findsOneWidget);

    await tester.tap(find.text('Reenviar correo'));
    await tester.pumpAndSettle();

    expect(fixture.apiClient.requests.map((request) => request.path), [
      '/user/login',
      '/user/resend-verification-email',
    ]);
    expect(fixture.apiClient.requests.last.body, {
      'email': 'persona@bond.test',
    });
    expect(find.textContaining('se envió un nuevo enlace'), findsOneWidget);
  });

  testWidgets('solicita edad al iniciar sesión con una cuenta existente', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.apiClient.requireAgeVerification = true;
    addTearDown(fixture.authProvider.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: ChangeNotifierProvider<AuthProvider>.value(
          value: fixture.authProvider,
          child: MaterialApp(home: const LoginScreen()),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'persona@bond.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(fixture.authProvider.ageVerificationRequired, isTrue);
    expect(find.text('Ingrese su fecha de nacimiento'), findsOneWidget);
    expect(
      fixture.apiClient.requests.single.body.containsKey('birthDate'),
      isFalse,
    );

    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(fixture.authProvider.termsAcceptanceRequired, isTrue);
    expect(find.text('Términos de uso'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      fixture.apiClient.requests[1].body['birthDate'],
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
    expect(
      fixture.apiClient.requests[1].body.containsKey('termsVersion'),
      isFalse,
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(
      fixture.apiClient.requests.last.body['termsVersion'],
      termsOfUseVersion,
    );
    expect(fixture.authProvider.termsAcceptanceRequired, isFalse);
  });

  test('canjea el enlace por una sesión autenticada', () async {
    final fixture = _Fixture();
    addTearDown(fixture.authProvider.dispose);

    final authenticated = await fixture.authProvider.completeEmailVerification(
      token: List.filled(64, 'a').join(),
    );

    expect(authenticated, isTrue);
    expect(
      fixture.apiClient.requests.single.path,
      '/user/verify-email-session',
    );
    expect(fixture.apiClient.requests.single.body, {
      'token': List.filled(64, 'a').join(),
    });
    expect(fixture.storage.savedSessionToken, 'verified-session-token');
    expect(
      fixture.authProvider.authResponse?.sessionToken,
      'verified-session-token',
    );
  });
}
