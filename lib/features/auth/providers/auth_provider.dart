import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../services/auth_service.dart';
import '../services/session_state_cleanup.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SessionStateCleanup _sessionStateCleanup;

  AuthProvider(this._authService, this._sessionStateCleanup);

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
    isLoading = true;
    errorMessage = null;
    authResponse = null;
    notifyListeners();

    try {
      final request = LoginRequest(email: email, password: password);

      authResponse = await _authService.login(request);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSession() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      authResponse = await _authService.restoreSession();

      return authResponse != null;
    } catch (error) {
      authResponse = null;
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logout() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.logout();
      await _finishSession();

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
