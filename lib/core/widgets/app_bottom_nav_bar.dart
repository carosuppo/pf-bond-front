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
    required this.tooltip,
  });

  final AppBottomDestination destination;
  final IconData icon;
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
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bottomBarBackground,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [for (final item in _items) _buildButton(item)],
        ),
      ),
    );
  }

  Widget _buildButton(_BottomNavItem item) {
    final isSelected = item.destination == selectedDestination;

    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.6) : null,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: item.tooltip,
        onPressed: isSelected
            ? null
            : () => onDestinationSelected(item.destination),
        padding: EdgeInsets.zero,
        icon: Icon(
          item.icon,
          color: isSelected
              ? AppColors.onPrimary
              : AppColors.bottomBarIconInactive,
          size: 28,
        ),
      ),
    );
  }
}
