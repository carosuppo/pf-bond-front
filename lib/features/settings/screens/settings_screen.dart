import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../models/settings_option.dart';
import '../widgets/settings_option_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Opciones disponibles en la pantalla.
  ///
  /// Agregar una nueva opción es tan simple como agregar un elemento a esta
  /// lista (abierta a extensión, cerrada a modificación).
  List<SettingsOption> _buildOptions(BuildContext context) {
    return [
      SettingsOption(
        icon: Icons.person_outline,
        title: 'Modificar mi perfil',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final options = _buildOptions(context);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Configuración'),
      ),
      body: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) =>
            SettingsOptionTile(option: options[index]),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedDestination: AppBottomDestination.settings,
        onDestinationSelected: (destination) =>
            navigateToAppDestination(context, destination),
      ),
    );
  }
}
