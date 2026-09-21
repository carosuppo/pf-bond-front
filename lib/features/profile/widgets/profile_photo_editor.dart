import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/widgets/auth_submit_button.dart';

class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.name,
    required this.currentPhotoUrl,
    required this.selectedPhoto,
    required this.isSaving,
    this.previewRadius = 54,
    required this.onGallery,
    required this.onCamera,
    required this.onConfirm,
    required this.onCancel,
  });

  final String name;
  final String? currentPhotoUrl;
  final XFile? selectedPhoto;
  final bool isSaving;
  final double previewRadius;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PhotoPreview(
          name: name,
          currentPhotoUrl: currentPhotoUrl,
          selectedPhoto: selectedPhoto,
          radius: previewRadius,
        ),
        const SizedBox(height: 12),
        const Text(
          'Elegí una foto para personalizar tu perfil',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Cámara'),
              ),
            ),
          ],
        ),
        if (selectedPhoto != null) ...[
          const SizedBox(height: 12),
          AuthSubmitButton(
            text: 'Confirmar foto',
            isLoading: isSaving,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: isSaving ? null : onCancel,
            child: const Text('Cancelar selección'),
          ),
        ],
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.name,
    required this.currentPhotoUrl,
    required this.selectedPhoto,
    required this.radius,
  });

  final String name;
  final String? currentPhotoUrl;
  final XFile? selectedPhoto;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = selectedPhoto;

    if (photo == null) {
      return UserAvatar(name: name, photoUrl: currentPhotoUrl, radius: radius);
    }

    return ClipOval(
      child: Image.file(
        File(photo.path),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            UserAvatar(name: name, photoUrl: currentPhotoUrl, radius: radius),
      ),
    );
  }
}
