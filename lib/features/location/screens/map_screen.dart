import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_route_arguments.dart';
import '../providers/location_provider.dart';
import '../widgets/location_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  final MapRouteArguments? arguments;

  const MapScreen({super.key, required this.arguments});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  void initState() {
    super.initState();
    final groupId = widget.arguments?.groupId;
    if (groupId != null) {
      Future.microtask(
        () => ref.read(locationProvider.notifier).startViewingGroup(groupId),
      );
    }
  }

  @override
  void dispose() {
    Future.microtask(
      () => ref.read(locationProvider.notifier).stopViewingGroup(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.arguments?.groupId;
    if (groupId == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Selecciona un grupo para ver su mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text),
              ),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(locationProvider);
    final sharing = state.sharingForGroup(groupId);
    ref.listen(locationProvider.select((value) => value.errorMessage), (
      _,
      error,
    ) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.arguments?.groupName ?? 'Ubicaciones')),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Compartir ubicacion'),
              subtitle: sharing?.shareLocationMandatorily == true
                  ? const Text('Obligatorio para este grupo')
                  : null,
              value: sharing?.effectiveLocationSharing ?? false,
              onChanged:
                  state.isLoading ||
                      sharing == null ||
                      sharing.shareLocationMandatorily
                  ? null
                  : (enabled) => ref
                        .read(locationProvider.notifier)
                        .setGroupSharing(groupId, enabled),
            ),
            Expanded(child: LocationMap(groupId: groupId)),
          ],
        ),
      ),
    );
  }
}
