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

  Future<bool> loadProfileAndGroups() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userFuture = _profileService.getCurrentUser();
      final groupsFuture = _groupService.getGroups();

      final loadedUser = await userFuture;
      final loadedGroups = await groupsFuture;

      user = loadedUser;
      groups = loadedGroups;

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
