import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/profile_photo_editor.dart';
import '../models/settings_option.dart';
import '../widgets/settings_option_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _showPhotoEditor(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ProfilePhotoEditorModal(),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthProvider>();
    if (auth.isDeletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Tu cuenta y tus datos personales asociados se eliminarán '
          'permanentemente. Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar cuenta',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await auth.deleteAccount();
    if (!mounted) return;
    if (success) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'No se pudo eliminar la cuenta.'),
        ),
      );
    }
  }

  Future<void> _showProfilePhoto(BuildContext context) async {
    final user = context.read<AuthProvider>().authResponse?.user;

    if (user == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) => _ProfilePhotoViewer(
        user: user,
        onEdit: () {
          Navigator.of(dialogContext).pop();
          _showPhotoEditor(context);
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.logout();

    if (!context.mounted) {
      return;
    }

    if (success) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          authProvider.errorMessage ?? 'No se pudo cerrar la sesión.',
        ),
      ),
    );
  }

  List<SettingsOption> _buildOptions(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return [
      SettingsOption(
        icon: Icons.person_outline,
        title: 'Modificar mi perfil',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
      ),
      SettingsOption(
        icon: Icons.notifications_outlined,
        title: 'Notificaciones',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
      ),
      SettingsOption(
        icon: Icons.lock_outline,
        title: 'Modificar mi contraseña',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.changePassword),
      ),
      SettingsOption(
        icon: Icons.logout,
        title: authProvider.isLoading ? 'Cerrando sesión...' : 'Cerrar sesión',
        onTap: authProvider.isLoading ? null : () => _logout(context),
        isDestructive: true,
      ),
      SettingsOption(
        icon: Icons.delete_forever_outlined,
        title: 'Eliminar cuenta',
        isDestructive: true,
        onTap: authProvider.isDeletingAccount ? null : _deleteAccount,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final options = _buildOptions(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: const Text(
                      'Configuración',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _ProfileSummary(
              user: authProvider.authResponse?.user,
              onViewPhoto: () => _showProfilePhoto(context),
              onEditPhoto: () => _showPhotoEditor(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, index) => Divider(
                  height: index == options.length - 2 ? 24 : 1,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, index) =>
                    SettingsOptionTile(option: options[index]),
              ),
            ),
            if (context.watch<AuthProvider>().isDeletingAccount)
              const LinearProgressIndicator(color: AppColors.error),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.user,
    required this.onViewPhoto,
    required this.onEditPhoto,
  });

  final UserModel? user;
  final VoidCallback onViewPhoto;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Usuario';

    return Column(
      children: [
        SizedBox(
          width: 116,
          height: 116,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: GestureDetector(
                  onTap: onViewPhoto,
                  child: UserAvatar(
                    name: name,
                    photoUrl: user?.profilePhoto,
                    radius: 52,
                    borderColor: Colors.white,
                    borderWidth: 1,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Tooltip(
                  message: 'Editar foto de perfil',
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onEditPhoto,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: Icon(Icons.add, color: Colors.black, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
      ],
    );
  }
}

class _ProfilePhotoViewer extends StatelessWidget {
  const _ProfilePhotoViewer({required this.user, required this.onEdit});

  final UserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: UserAvatar(
                name: user.name,
                photoUrl: user.profilePhoto,
                radius: 140,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    tooltip: 'Editar foto de perfil',
                    color: Colors.white,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoEditorModal extends StatefulWidget {
  const _ProfilePhotoEditorModal();

  @override
  State<_ProfilePhotoEditorModal> createState() =>
      _ProfilePhotoEditorModalState();
}

class _ProfilePhotoEditorModalState extends State<_ProfilePhotoEditorModal> {
  Future<void> _pickFromGallery() async {
    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.pickProfilePhotoFromGallery();

    if (!mounted || success || profileProvider.errorMessage == null) {
      return;
    }

    _showMessage(profileProvider.errorMessage!);
  }

  Future<void> _pickFromCamera() async {
    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.pickProfilePhotoFromCamera();

    if (!mounted || success || profileProvider.errorMessage == null) {
      return;
    }

    _showMessage(profileProvider.errorMessage!);
  }

  Future<void> _savePhoto() async {
    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.saveProfilePhoto();

    if (!mounted) {
      return;
    }

    if (!success) {
      _showMessage(
        profileProvider.errorMessage ?? 'No se pudo actualizar la foto.',
      );
      return;
    }

    final updatedUser = profileProvider.user;
    if (updatedUser != null) {
      context.read<AuthProvider>().updateUser(updatedUser);
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final user = context.watch<AuthProvider>().authResponse?.user;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          children: [
            const Text(
              'Editar foto de perfil',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ProfilePhotoEditor(
              name: user?.name ?? 'Usuario',
              currentPhotoUrl: user?.profilePhoto,
              selectedPhoto: profileProvider.selectedPhoto,
              isSaving: profileProvider.isSavingPhoto,
              onGallery: _pickFromGallery,
              onCamera: _pickFromCamera,
              onConfirm: _savePhoto,
              onCancel: profileProvider.clearSelectedPhoto,
            ),
          ],
        ),
      ),
    );
  }
}
