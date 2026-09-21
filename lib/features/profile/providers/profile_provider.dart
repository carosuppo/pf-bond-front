import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/models/user_model.dart';
import '../../group/models/get_groups_model.response.dart';
import '../../group/services/group_service.dart';
import '../models/update_profile_request.dart';
import '../services/profile_photo_picker_service.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;
  final GroupService _groupService;
  final ProfilePhotoPickerService _photoPickerService;

  ProfileProvider(
    this._profileService,
    this._groupService, [
    ProfilePhotoPickerService? photoPickerService,
  ]) : _photoPickerService = photoPickerService ?? ProfilePhotoPickerService();

  bool isLoading = false;
  bool isSaving = false;
  bool isSavingPhoto = false;
  String? errorMessage;
  UserModel? user;
  List<GetGroupsResponseModel> groups = [];
  int _sessionVersion = 0;
  XFile? _selectedPhoto;

  XFile? get selectedPhoto => _selectedPhoto;

  void resetSessionState() {
    _sessionVersion++;
    isLoading = false;
    isSaving = false;
    errorMessage = null;
    user = null;
    groups = [];
    _selectedPhoto = null;
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

  Future<bool> pickProfilePhotoFromGallery() async {
    return _pickProfilePhoto(_photoPickerService.pickFromGallery);
  }

  Future<bool> pickProfilePhotoFromCamera() async {
    return _pickProfilePhoto(_photoPickerService.pickFromCamera);
  }

  Future<bool> _pickProfilePhoto(Future<XFile?> Function() picker) async {
    errorMessage = null;

    try {
      final photo = await picker();

      if (photo == null) {
        return false;
      }

      _selectedPhoto = photo;

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> saveProfilePhoto() async {
    final photo = _selectedPhoto;

    if (photo == null) {
      return false;
    }

    isSavingPhoto = true;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _profileService.updateProfilePhoto(
        photo.path,
        mimeType: photo.mimeType,
      );
      _selectedPhoto = null;

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isSavingPhoto = false;
      notifyListeners();
    }
  }

  void clearSelectedPhoto() {
    if (_selectedPhoto == null) {
      return;
    }

    _selectedPhoto = null;
    errorMessage = null;
    notifyListeners();
  }
}
