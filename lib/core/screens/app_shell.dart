import 'package:flutter/material.dart';

import '../../features/event/screens/events_screen.dart';
import '../../features/location/screens/map_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialDestination = AppBottomDestination.map,
  });

  final AppBottomDestination initialDestination;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDestination.index;
  }

  void _selectDestination(AppBottomDestination destination) {
    if (_selectedIndex == destination.index) {
      return;
    }

    setState(() {
      _selectedIndex = destination.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [MapScreen(), EventsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavBar(
          selectedDestination: AppBottomDestination.values[_selectedIndex],
          onDestinationSelected: _selectDestination,
        ),
      ),
    );
  }
}
