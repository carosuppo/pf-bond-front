import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../models/update_profile_request.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;

  ProfileProvider(this._profileService);

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  UserModel? user;

  Future<bool> loadProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _profileService.getCurrentUser();

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({String? name, String? email}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _profileService.updateCurrentUser(
        UpdateProfileRequest(name: name, email: email),
      );

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
