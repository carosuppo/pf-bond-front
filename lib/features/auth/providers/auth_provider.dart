import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  bool isLoading = false;
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
      authResponse = null;

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
