import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

enum AppBottomDestination { map, settings }

extension AppBottomDestinationRoute on AppBottomDestination {
  String get route => switch (this) {
    AppBottomDestination.map => AppRoutes.map,
    AppBottomDestination.settings => AppRoutes.settings,
  };
}

void navigateToAppDestination(
  BuildContext context,
  AppBottomDestination destination,
) {
  Navigator.of(context).pushReplacementNamed(destination.route);
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.destination,
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
  });

  final AppBottomDestination destination;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  static const _items = [
    _BottomNavItem(
      destination: AppBottomDestination.map,
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on,
      tooltip: 'Ubicación',
    ),
    _BottomNavItem(
      destination: AppBottomDestination.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      tooltip: 'Configuración',
    ),
  ];

  final AppBottomDestination selectedDestination;
  final ValueChanged<AppBottomDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bottomBarBackground,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [for (final item in _items) _buildButton(item)],
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
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      icon: Icon(
        isSelected ? item.selectedIcon : item.icon,
        size: 30,
        color: Colors.white,
      ),
    );
  }
}
