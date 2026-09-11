import 'dart:async';

import 'package:bond_front/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../group/models/get_member_info_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../../group/services/group_service.dart';
import '../../group/widgets/group_info_bottom_sheet.dart';
import '../../group/widgets/group_selector_button.dart';
import '../../group/widgets/member_info_bottom_sheet.dart';
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
  int? _selectedMemberId;
  int _memberInfoRequestId = 0;
  bool _memberInfoLoading = false;
  GetMemberInfoResponseModel? _memberInfo;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _groupProvider.addListener(_onGroupChanged);

    _sheetController = DraggableScrollableController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewingGroup());
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

  void _handleMapTap() {
    _clearMemberInfo();
    _collapseSheet();
  }

  void _handleMemberTap(int memberId) {
    if (!mounted) {
      return;
    }

    final requestId = ++_memberInfoRequestId;

    setState(() {
      _selectedMemberId = memberId;
      _memberInfo = null;
      _memberInfoLoading = true;
    });

    _expandSheet();
    unawaited(_loadMemberInfo(memberId, requestId));
  }

  Future<void> _loadMemberInfo(int memberId, int requestId) async {
    try {
      final memberInfo = await context.read<GroupService>().getMemberInfo(
        memberId: memberId,
      );

      if (!mounted ||
          requestId != _memberInfoRequestId ||
          _selectedMemberId != memberId) {
        return;
      }

      setState(() {
        _memberInfo = memberInfo;
        _memberInfoLoading = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _memberInfoRequestId ||
          _selectedMemberId != memberId) {
        return;
      }

      _clearMemberInfo();
      _collapseSheet();

      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message.isEmpty
                  ? 'No se pudo consultar la información del miembro.'
                  : message,
            ),
          ),
        );
    }
  }

  void _clearMemberInfo() {
    _memberInfoRequestId++;

    if (_selectedMemberId == null &&
        _memberInfo == null &&
        !_memberInfoLoading) {
      return;
    }

    setState(() {
      _selectedMemberId = null;
      _memberInfo = null;
      _memberInfoLoading = false;
    });
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

  void _onGroupChanged() {
    final activeGroupId = _groupProvider.activeGroup?.id;

    if (activeGroupId != _viewingGroupId) {
      _clearMemberInfo();
    }

    _syncViewingGroup();
  }

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
                    onMapTap: _handleMapTap,
                    onMemberTap: _handleMemberTap,
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
                          // Manijita del panel.
                          //
                          // Esta zona controla directamente el tamaño del
                          // DraggableScrollableSheet, haciendo que el panel
                          // acompañe al dedo durante todo el gesto.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: _handleSheetDragUpdate,
                            onVerticalDragEnd: _handleSheetDragEnd,
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
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child: _memberInfoLoading
                                ? MemberInfoLoading(
                                    scrollController: scrollController,
                                  )
                                : _memberInfo != null
                                ? MemberInfoBottomSheet(
                                    memberInfo: _memberInfo!,
                                    scrollController: scrollController,
                                  )
                                : GroupInfoBottomSheet(
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
              navigateToAppDestination(context, destination),
        ),
      ),
    );
  }
}
