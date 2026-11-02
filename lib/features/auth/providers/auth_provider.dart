import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/session_state_cleanup.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SessionStateCleanup _sessionStateCleanup;

  AuthProvider(
    this._authService,
    this._sessionStateCleanup, {
    this.onSessionReady,
    this.onSessionEnding,
  });

  final Future<void> Function()? onSessionReady;
  final Future<void> Function()? onSessionEnding;

  int _sessionVersion = 0;

  bool isLoading = false;
  bool isChangingPassword = false;
  bool isDeletingAccount = false;
  bool emailVerificationRequired = false;
  bool ageVerificationRequired = false;
  bool termsAcceptanceRequired = false;
  bool isResendingVerificationEmail = false;
  String? errorMessage;
  String? resendVerificationErrorMessage;
  AuthResponse? authResponse;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String birthDate,
    required String termsVersion,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
        name: name,
        email: email,
        password: password,
        birthDate: birthDate,
        termsVersion: termsVersion,
      );

      await _authService.register(request);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    String? birthDate,
    String? termsVersion,
  }) async {
    return _establishSession(
      () => _authService.login(
        LoginRequest(
          email: email,
          password: password,
          birthDate: birthDate,
          termsVersion: termsVersion,
        ),
      ),
    );
  }

  void cancelAgeVerification() {
    ageVerificationRequired = false;
    errorMessage = null;
    notifyListeners();
  }

  void cancelTermsAcceptance() {
    termsAcceptanceRequired = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> completeEmailVerification({required String token}) async {
    return _establishSession(
      () => _authService.completeEmailVerification(token),
      showEligibilitySteps: false,
    );
  }

  Future<bool> _establishSession(
    Future<AuthResponse> Function() authenticate, {
    bool showEligibilitySteps = true,
  }) async {
    final version = ++_sessionVersion;
    isLoading = true;
    errorMessage = null;
    emailVerificationRequired = false;
    resendVerificationErrorMessage = null;
    authResponse = null;
    notifyListeners();

    try {
      final response = await authenticate();
      if (version != _sessionVersion) return false;
      ageVerificationRequired = false;
      termsAcceptanceRequired = false;
      authResponse = response;
      await onSessionReady?.call();
      if (version != _sessionVersion) return false;

      return true;
    } catch (error) {
      if (version != _sessionVersion) return false;
      ageVerificationRequired =
          showEligibilitySteps &&
          error is ApiException &&
          error.message == 'AGE_VERIFICATION_REQUIRED';
      termsAcceptanceRequired =
          showEligibilitySteps &&
          error is ApiException &&
          error.message == 'TERMS_ACCEPTANCE_REQUIRED';
      emailVerificationRequired =
          error is ApiException &&
          error.statusCode == 403 &&
          error.message.contains('verificar tu correo electrónico');
      errorMessage = ageVerificationRequired
          ? 'Completá la verificación de fecha de nacimiento para continuar.'
          : termsAcceptanceRequired
          ? 'Aceptá los Términos de uso para continuar.'
          : !showEligibilitySteps &&
                error is ApiException &&
                (error.message == 'AGE_VERIFICATION_REQUIRED' ||
                    error.message == 'TERMS_ACCEPTANCE_REQUIRED')
          ? 'El correo quedó verificado. Iniciá sesión para completar la validación de tu cuenta.'
          : error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (version == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> resendVerificationEmail({required String email}) async {
    isResendingVerificationEmail = true;
    resendVerificationErrorMessage = null;
    notifyListeners();

    try {
      await _authService.resendVerificationEmail(email);
      return true;
    } catch (error) {
      resendVerificationErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      isResendingVerificationEmail = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSession() async {
    final version = ++_sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.restoreSession();
      if (version != _sessionVersion) return false;
      authResponse = response;
      if (authResponse != null) await onSessionReady?.call();
      if (version != _sessionVersion) return false;

      return authResponse != null;
    } catch (error) {
      if (version != _sessionVersion) return false;
      authResponse = null;
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      if (version == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> invalidateExpiredSession() async {
    errorMessage = null;
    await _finishSession();
  }

  Future<bool> logout() async {
    _sessionVersion++;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await onSessionEnding?.call();
      try {
        await _authService.logout();
      } finally {
        await _finishSession();
      }

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isChangingPassword = true;
    errorMessage = null;
    notifyListeners();

    try {
      final request = ChangePasswordRequest(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      await _authService.changePassword(request);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isChangingPassword = false;
      notifyListeners();
    }
  }

  void updateUser(UserModel user) {
    final currentResponse = authResponse;

    if (currentResponse == null) {
      return;
    }

    authResponse = AuthResponse(
      sessionToken: currentResponse.sessionToken,
      expiresAt: currentResponse.expiresAt,
      user: user,
    );
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    if (isDeletingAccount) return false;
    isDeletingAccount = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
      await _finishSession();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isDeletingAccount = false;
      notifyListeners();
    }
  }

  Future<void> _finishSession() async {
    _sessionVersion++;
    authResponse = null;
    notifyListeners();
    try {
      await _sessionStateCleanup.clear();
    } catch (error, stackTrace) {
      debugPrint('No se pudo completar la limpieza local de sesión: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
