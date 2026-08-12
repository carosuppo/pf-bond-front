import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../group/providers/group_provider.dart';
import '../../group/widgets/group_selector_button.dart';
import '../providers/location_provider.dart';
import '../widgets/location_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(locationProvider.notifier).initialize();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<GroupProvider>().getGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: LocationMap()),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: GroupSelectorButton(
                selectedGroupName:
                    groupProvider.activeGroup?.name ?? 'Seleccionar grupo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
