import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_bottom_nav_bar.dart';
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
  late final GroupProvider _groupProvider;
  int? _viewingGroupId;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _groupProvider.addListener(_onGroupChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewingGroup());
  }

  void _onGroupChanged() => _syncViewingGroup();

  void _syncViewingGroup() {
    if (!mounted) return;

    final activeGroupId = _groupProvider.activeGroup?.id;

    if (activeGroupId == _viewingGroupId) return;

    _viewingGroupId = activeGroupId;

    final locationNotifier = ref.read(locationProvider.notifier);

    if (activeGroupId == null) {
      locationNotifier.stopViewingGroup();
    } else {
      locationNotifier.startViewingGroup(activeGroupId);
    }
  }

  @override
  void dispose() {
    _groupProvider.removeListener(_onGroupChanged);

    if (_viewingGroupId != null) {
      ref.read(locationProvider.notifier).stopViewingGroup();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: LocationMap(groupId: groupProvider.activeGroup?.id),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: const GroupSelectorButton(),
            ),
            if (groupProvider.groupDetails != null)
              Positioned.fill(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.25,
                  minChildSize: 0.25,
                  maxChildSize: 0.6,
                  snap: true,
                  snapSizes: const [0.25, 0.6],
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
      bottomNavigationBar: AppBottomNavBar(
        selectedDestination: AppBottomDestination.map,
        onDestinationSelected: (destination) =>
            navigateToAppDestination(context, destination),
      ),
    );
  }
}
