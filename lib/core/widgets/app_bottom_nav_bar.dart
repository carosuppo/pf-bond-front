import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

enum AppBottomDestination { map, events, settings }

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
      destination: AppBottomDestination.events,
      icon: Icons.event_outlined,
      selectedIcon: Icons.event_rounded,
      tooltip: 'Eventos',
    ),
    _BottomNavItem(
      destination: AppBottomDestination.settings,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
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
        color: AppColors.background,
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
        children: [for (final item in _items) _buildButton(context, item)],
      ),
    );
  }

  Widget _buildButton(BuildContext context, _BottomNavItem item) {
    final isSelected = item.destination == selectedDestination;
    final user = item.destination == AppBottomDestination.settings
        ? context.watch<AuthProvider>().authResponse?.user
        : null;

    return IconButton(
      tooltip: item.tooltip,
      onPressed: isSelected
          ? null
          : () => onDestinationSelected(item.destination),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      icon: item.destination == AppBottomDestination.settings
          ? UserAvatar(
              name: user?.name ?? '',
              photoUrl: user?.profilePhoto,
              radius: 15,
              borderColor: isSelected ? Colors.white : null,
              borderWidth: isSelected ? 1 : 0,
            )
          : Icon(
              isSelected ? item.selectedIcon : item.icon,
              size: 30,
              color: Colors.white,
            ),
    );
  }
}
