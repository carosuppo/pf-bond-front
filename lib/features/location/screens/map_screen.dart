import 'package:bond_front/core/theme/app_colors.dart';
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
  static const _minChildSize = 0.2;
  static const _maxChildSize = 0.5;

  late final GroupProvider _groupProvider;
  late final DraggableScrollableController _sheetController;
  ScrollController? _sheetScrollController;

  int? _viewingGroupId;
  bool _sheetExpanded = false;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _groupProvider.addListener(_onGroupChanged);

    _sheetController = DraggableScrollableController()
      ..addListener(_onSheetSizeChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewingGroup());
  }

  void _onSheetSizeChanged() {
    final expanded = _sheetController.size >= _maxChildSize - 0.001;

    if (expanded == _sheetExpanded) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() => _sheetExpanded = expanded);
    });
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;

    // Primero colapsa la hoja: animateTo ejecuta goIdle() de forma síncrona,
    // lo que cancelaría una animación de scroll en curso. Por eso el scroll
    // al tope se inicia después.
    _sheetController.animateTo(
      _minChildSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    if (_sheetScrollController?.hasClients ?? false) {
      _sheetScrollController!.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    _sheetController.dispose();

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
              child: Stack(
                children: [
                  LocationMap(groupId: groupProvider.activeGroup?.id),
                  // Barrera transparente: si la hoja está en su tamaño máximo,
                  // tocar fuera de ella la colapsa al mínimo. Va dentro del
                  // mismo Positioned.fill para no reordenar los hijos del
                  // Stack principal (evita re-montar la hoja).
                  if (groupProvider.groupDetails != null && _sheetExpanded)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _collapseSheet,
                      ),
                    ),
                ],
              ),
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
                  controller: _sheetController,
                  initialChildSize: _minChildSize,
                  minChildSize: _minChildSize,
                  maxChildSize: _maxChildSize,
                  snap: true,
                  snapSizes: const [_minChildSize, _maxChildSize],
                  builder: (context, scrollController) {
                    _sheetScrollController = scrollController;

                    return Material(
                      elevation: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,

                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppColors.mutedText,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GroupInfoBottomSheet(
                              group: groupProvider.groupDetails!,
                              scrollController: scrollController,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: AppBottomNavBar(
                  selectedDestination: AppBottomDestination.map,
                  onDestinationSelected: (destination) =>
                      navigateToAppDestination(context, destination),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
