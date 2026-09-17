import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/settings_option.dart';
import '../widgets/settings_option_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  List<SettingsOption> _buildOptions(BuildContext context) {
    return [
      SettingsOption(
        icon: Icons.account_circle_outlined,
        title: 'Ver mi perfil',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
      ),
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
        icon: Icons.delete_forever_outlined,
        title: 'Eliminar cuenta',
        isDestructive: true,
        onTap: context.watch<AuthProvider>().isDeletingAccount
            ? null
            : _deleteAccount,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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

      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavBar(
          selectedDestination: AppBottomDestination.settings,
          onDestinationSelected: (destination) =>
              navigateToAppDestination(context, destination),
        ),
      ),
    );
  }
}
