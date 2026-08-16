import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Destinos disponibles en la barra de navegación inferior.
enum AppBottomDestination { map, settings }

/// Mapea cada destino a su ruta correspondiente.
extension AppBottomDestinationRoute on AppBottomDestination {
  String get route => switch (this) {
    AppBottomDestination.map => AppRoutes.map,
    AppBottomDestination.settings => AppRoutes.settings,
  };
}

/// Navega al destino reemplazando la ruta actual, de modo que la barra
/// inferior se comporte como pestañas de la aplicación.
void navigateToAppDestination(
  BuildContext context,
  AppBottomDestination destination,
) {
  Navigator.of(context).pushReplacementNamed(destination.route);
}

/// Ítem de la barra de navegación inferior.
class _BottomNavItem {
  const _BottomNavItem({
    required this.destination,
    required this.icon,
    required this.tooltip,
  });

  final AppBottomDestination destination;
  final IconData icon;
  final String tooltip;
}

/// Barra de navegación inferior de la aplicación.
///
/// Para agregar un nuevo destino alcanza con: agregar un valor al enum
/// [AppBottomDestination], mapear su ruta en la extensión y agregar un
/// elemento a [_items] (abierta a extensión, cerrada a modificación).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  static const _items = [
    _BottomNavItem(
      destination: AppBottomDestination.map,
      icon: Icons.map,
      tooltip: 'Mapa',
    ),
    _BottomNavItem(
      destination: AppBottomDestination.settings,
      icon: Icons.settings,
      tooltip: 'Configuración',
    ),
  ];

  final AppBottomDestination selectedDestination;
  final ValueChanged<AppBottomDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bottomBarBackground,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 40,
          children: [for (final item in _items) _buildButton(item)],
        ),
      ),
    );
  }

  Widget _buildButton(_BottomNavItem item) {
    final isSelected = item.destination == selectedDestination;

    return IconButton(
      tooltip: item.tooltip,
      onPressed: isSelected
          ? null
          : () => onDestinationSelected(item.destination),
      icon: Icon(
        item.icon,
        color: isSelected ? AppColors.primary : AppColors.bottomBarIconInactive,
        size: 28,
      ),
    );
  }
}
