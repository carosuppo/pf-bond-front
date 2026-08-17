import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../group/providers/group_provider.dart';
import '../../group/widgets/group_info_bottom_sheet.dart';
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

      // MapScreen es actualmente el punto de entrada al área autenticada (pantalla inicial).
      // Por eso inicializa el estado de grupos una sola vez mediante
      // GroupProvider.initialize(), evitando que cada pantalla tenga
      // que encargarse de cargar los grupos para mostrarlos en el GroupSelectorButton (Consultar mis grupos).
      context.read<GroupProvider>().initialize();
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
              child: const GroupSelectorButton(),
            ),
            if (groupProvider.groupDetails != null)
              Positioned.fill(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.12,
                  minChildSize: 0.12,
                  maxChildSize: 0.6,
                  snap: true,
                  snapSizes: const [0.12, 0.6],
                  builder: (context, scrollController) {
                    return Material(
                      elevation: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GroupInfoBottomSheet(
                        group: groupProvider.groupDetails!,
                        scrollController: scrollController,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
