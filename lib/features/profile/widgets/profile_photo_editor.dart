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
    this.selectionDescription = 'Elegí una foto para personalizar tu perfil',
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
  final String selectionDescription;
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
        Text(
          selectionDescription,
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

class PhotoEditButton extends StatelessWidget {
  const PhotoEditButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 26,
            height: 26,
            child: Icon(Icons.add, color: Colors.black, size: 18),
          ),
        ),
      ),
    );
  }
}

class PhotoEditorModal extends StatefulWidget {
  const PhotoEditorModal({
    super.key,
    required this.title,
    required this.name,
    required this.currentPhotoUrl,
    required this.selectedPhoto,
    required this.isSaving,
    required this.errorMessage,
    required this.onGallery,
    required this.onCamera,
    required this.onConfirm,
    required this.onCancel,
    this.selectionDescription = 'Elegí una foto para personalizar tu perfil',
  });

  final String title;
  final String name;
  final String? currentPhotoUrl;
  final XFile? selectedPhoto;
  final bool isSaving;
  final String? errorMessage;
  final Future<bool> Function() onGallery;
  final Future<bool> Function() onCamera;
  final Future<bool> Function() onConfirm;
  final VoidCallback onCancel;
  final String selectionDescription;

  @override
  State<PhotoEditorModal> createState() => _PhotoEditorModalState();
}

class _PhotoEditorModalState extends State<PhotoEditorModal> {
  Future<void> _pick(Future<bool> Function() picker) async {
    final success = await picker();

    if (!mounted || success || widget.errorMessage == null) {
      return;
    }

    _showMessage(widget.errorMessage!);
  }

  Future<void> _save() async {
    final success = await widget.onConfirm();

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    _showMessage(widget.errorMessage ?? 'No se pudo actualizar la imagen.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ProfilePhotoEditor(
              name: widget.name,
              currentPhotoUrl: widget.currentPhotoUrl,
              selectedPhoto: widget.selectedPhoto,
              isSaving: widget.isSaving,
              selectionDescription: widget.selectionDescription,
              onGallery: () => _pick(widget.onGallery),
              onCamera: () => _pick(widget.onCamera),
              onConfirm: _save,
              onCancel: widget.onCancel,
            ),
          ],
        ),
      ),
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
