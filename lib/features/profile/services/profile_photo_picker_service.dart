import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/profile_photo_constants.dart';

class ProfilePhotoPickerException implements Exception {
  final String message;

  const ProfilePhotoPickerException(this.message);

  @override
  String toString() => message;
}

class ProfilePhotoPickerService {
  final ImagePicker _imagePicker;

  ProfilePhotoPickerService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  Future<XFile?> pickFromGallery() async {
    await _requestGalleryPermission();

    return _pickImage(ImageSource.gallery);
  }

  Future<XFile?> pickFromCamera() async {
    final permission = await Permission.camera.request();

    if (!permission.isGranted) {
      throw const ProfilePhotoPickerException(
        'Necesitás permitir el acceso a la cámara para tomar una foto.',
      );
    }

    return _pickImage(ImageSource.camera);
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image == null) {
      return null;
    }

    final size = await image.length();

    if (size > maxProfilePhotoSize) {
      throw const ProfilePhotoPickerException(
        'La imagen no puede superar los 5 MB.',
      );
    }

    final extension = image.name.toLowerCase().split('.').last;
    const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
    final mimeType = image.mimeType?.toLowerCase();

    final hasAllowedExtension = allowedExtensions.contains(extension);
    final hasAllowedMimeType = switch (mimeType) {
      'image/jpg' || 'image/jpeg' || 'image/png' || 'image/webp' => true,
      _ => false,
    };

    if (!hasAllowedExtension && !hasAllowedMimeType) {
      throw const ProfilePhotoPickerException(
        'El formato debe ser JPG, PNG o WebP.',
      );
    }

    return image;
  }

  Future<void> _requestGalleryPermission() async {
    final photosPermission = await Permission.photos.request();

    if (photosPermission.isGranted || photosPermission.isLimited) {
      return;
    }

    final storagePermission = await Permission.storage.request();

    if (storagePermission.isGranted) {
      return;
    }

    throw const ProfilePhotoPickerException(
      'Necesitás permitir el acceso a las imágenes para elegir una foto.',
    );
  }
}
