import 'package:flutter/material.dart';

import '../../features/event/screens/events_screen.dart';
import '../../features/documentation/screens/documentation_group_screen.dart';
import '../../features/expense_account/screens/expense_accounts_screen.dart';
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
  int _previousDocumentationIndex = AppBottomDestination.map.index;
  bool _documentationVisited = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDestination.index;
    _documentationVisited =
        widget.initialDestination == AppBottomDestination.documentation;
  }

  void _selectDestination(AppBottomDestination destination) {
    if (_selectedIndex == destination.index) {
      return;
    }

    setState(() {
      if (destination == AppBottomDestination.documentation) {
        _previousDocumentationIndex = _selectedIndex;
        _documentationVisited = true;
      }
      _selectedIndex = destination.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const MapScreen(),
          const EventsScreen(),
          const ExpenseAccountsScreen(),
          if (_documentationVisited)
            DocumentationGroupScreen(
              isActive:
                  _selectedIndex == AppBottomDestination.documentation.index,
              onExit: () =>
                  setState(() => _selectedIndex = _previousDocumentationIndex),
            )
          else
            const SizedBox.shrink(),
          const SettingsScreen(),
        ],
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
