import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../models/settings_option.dart';
import '../widgets/settings_option_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
