import 'package:flutter/material.dart';

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
  String? errorMessage;
  AuthResponse? authResponse;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
        name: name,
        email: email,
        password: password,
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

  Future<bool> login({required String email, required String password}) async {
    final version = ++_sessionVersion;
    isLoading = true;
    errorMessage = null;
    authResponse = null;
    notifyListeners();

    try {
      final request = LoginRequest(email: email, password: password);

      final response = await _authService.login(request);
      if (version != _sessionVersion) return false;
      authResponse = response;
      await onSessionReady?.call();
      if (version != _sessionVersion) return false;

      return true;
    } catch (error) {
      if (version != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (version == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
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
