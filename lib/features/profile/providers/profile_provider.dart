import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/models/user_model.dart';
import '../models/update_profile_request.dart';
import '../services/profile_photo_picker_service.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;
  final ProfilePhotoPickerService _photoPickerService;

  ProfileProvider(this._profileService, this._photoPickerService);

  bool isLoading = false;
  bool isSaving = false;
  bool isSavingPhoto = false;
  String? errorMessage;
  UserModel? user;
  XFile? _selectedPhoto;

  XFile? get selectedPhoto => _selectedPhoto;

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
