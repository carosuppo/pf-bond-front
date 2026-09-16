import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/settings_option.dart';
import '../widgets/settings_option_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        icon: Icons.logout,
        title: authProvider.isLoading ? 'Cerrando sesión...' : 'Cerrar sesión',
        onTap: authProvider.isLoading ? null : () => _logout(context),
        isDestructive: true,
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
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) =>
                    SettingsOptionTile(option: options[index]),
              ),
            ),
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
