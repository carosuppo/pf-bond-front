import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../../group/models/get_groups_model.response.dart';
import '../../group/services/group_service.dart';
import '../models/update_profile_request.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;
  final GroupService _groupService;

  ProfileProvider(this._profileService, this._groupService);

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  UserModel? user;
  List<GetGroupsResponseModel> groups = [];
  int _sessionVersion = 0;

  void resetSessionState() {
    _sessionVersion++;
    isLoading = false;
    isSaving = false;
    errorMessage = null;
    user = null;
    groups = [];
    notifyListeners();
  }

  Future<bool> loadProfile() async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedUser = await _profileService.getCurrentUser();
      if (sessionVersion != _sessionVersion) return false;
      user = loadedUser;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadProfileAndGroups() async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userFuture = _profileService.getCurrentUser();
      final groupsFuture = _groupService.getGroups();

      final loadedUser = await userFuture;
      final loadedGroups = await groupsFuture;
      if (sessionVersion != _sessionVersion) return false;

      user = loadedUser;
      groups = loadedGroups;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateProfile({String? name, String? email}) async {
    final sessionVersion = _sessionVersion;
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _profileService.updateCurrentUser(
        UpdateProfileRequest(name: name, email: email),
      );
      if (sessionVersion != _sessionVersion) return false;
      user = updatedUser;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isSaving = false;
        notifyListeners();
      }
    }
  }
}
