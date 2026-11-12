import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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
  final ImageCropper _imageCropper;

  ProfilePhotoPickerService({
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _imageCropper = imageCropper ?? ImageCropper();

  Future<XFile?> pickFromGallery() async {
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

    final croppedImage = await _imageCropper.cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar encuadre',
          toolbarColor: const Color(0xFF0C1014),
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
      ],
    );

    if (croppedImage == null) {
      return null;
    }

    final result = XFile(croppedImage.path);
    final size = await result.length();

    if (size > maxProfilePhotoSize) {
      throw const ProfilePhotoPickerException(
        'La imagen no puede superar los 5 MB.',
      );
    }

    final extension = result.name.toLowerCase().split('.').last;
    const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
    final mimeType = result.mimeType?.toLowerCase();

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

    return result;
  }
}
