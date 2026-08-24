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

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncViewingGroup(),
    );
  }

  void _onSheetSizeChanged() {
    final expanded =
        _sheetController.size >= _maxChildSize - 0.001;

    if (expanded == _sheetExpanded) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sheetExpanded = expanded;
      });
    });
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) {
      return;
    }

    _sheetController.animateTo(
      _minChildSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );

    if (_sheetScrollController?.hasClients ?? false) {
      _sheetScrollController!.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _expandSheet() {
    if (!_sheetController.isAttached) {
      return;
    }

    _sheetController.animateTo(
      _maxChildSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handleSheetDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) {
      return;
    }

    final delta = details.primaryDelta ?? 0;

    final minPixels = _sheetController.sizeToPixels(_minChildSize);
    final maxPixels = _sheetController.sizeToPixels(_maxChildSize);

    // Al mover el dedo hacia abajo, delta es positivo,
    // por lo que reducimos la altura del panel.
    //
    // Al moverlo hacia arriba, delta es negativo,
    // por lo que aumentamos su altura.
    final nextPixels = (_sheetController.pixels - delta)
        .clamp(minPixels, maxPixels)
        .toDouble();

    final nextSize = _sheetController.pixelsToSize(nextPixels);

    _sheetController.jumpTo(nextSize);
  }

  void _handleSheetDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;

    // Si el usuario suelta realizando un gesto claro hacia abajo,
    // terminamos de cerrar el panel.
    if (velocity > 300) {
      _collapseSheet();
      return;
    }

    // Si lo suelta realizando un gesto claro hacia arriba,
    // terminamos de abrirlo.
    if (velocity < -300) {
      _expandSheet();
      return;
    }

    // Si lo suelta lentamente, se acomoda al estado más cercano.
    final middleSize = (_minChildSize + _maxChildSize) / 2;

    if (_sheetController.size < middleSize) {
      _collapseSheet();
    } else {
      _expandSheet();
    }
  }

  void _onGroupChanged() => _syncViewingGroup();

  void _syncViewingGroup() {
    if (!mounted) {
      return;
    }

    final activeGroupId = _groupProvider.activeGroup?.id;

    if (activeGroupId == _viewingGroupId) {
      return;
    }

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
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  LocationMap(
                    groupId: groupProvider.activeGroup?.id,
                  ),

                  // Si el panel está completamente desplegado,
                  // tocar el mapa lo vuelve a contraer.
                  if (groupProvider.groupDetails != null &&
                      _sheetExpanded)
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
                  snapSizes: const [
                    _minChildSize,
                    _maxChildSize,
                  ],
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
                          // Manijita del panel.
                          //
                          // Esta zona controla directamente el tamaño del
                          // DraggableScrollableSheet, haciendo que el panel
                          // acompañe al dedo durante todo el gesto.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate:
                                _handleSheetDragUpdate,
                            onVerticalDragEnd:
                                _handleSheetDragEnd,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 14,
                              ),
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.mutedText,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
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
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavBar(
          selectedDestination: AppBottomDestination.map,
          onDestinationSelected: (destination) =>
              navigateToAppDestination(
                context,
                destination,
              ),
        ),
      ),
    );
  }
}
