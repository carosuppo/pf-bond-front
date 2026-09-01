import 'package:bond_front/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../group/providers/group_provider.dart';
import '../../group/widgets/group_info_bottom_sheet.dart';
import '../../group/widgets/group_selector_button.dart';
import '../../point_of_interest/models/point_of_interest.dart';
import '../../point_of_interest/providers/point_of_interest_provider.dart';
import '../../point_of_interest/widgets/point_of_interest_editor.dart';
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
  static const _poiMinChildSize = 0.12;
  static const _poiMaxChildSize = 0.58;

  late final GroupProvider _groupProvider;
  late final DraggableScrollableController _sheetController;
  late final DraggableScrollableController _poiSheetController;

  ScrollController? _sheetScrollController;
  ScrollController? _poiSheetScrollController;

  int? _viewingGroupId;
  bool _sheetExpanded = false;

  final MapController _mapController = MapController();
  final GlobalKey<PointOfInterestEditorState> _editorKey = GlobalKey();

  PointOfInterest? _editingPoint;
  bool _editing = false;
  LatLng? _draftLocation;
  double _draftRadius = 100;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _groupProvider.addListener(_onGroupChanged);

    _sheetController = DraggableScrollableController()
      ..addListener(_onSheetSizeChanged);
    _poiSheetController = DraggableScrollableController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewingGroup());
  }

  void _onSheetSizeChanged() {
    final expanded = _sheetController.size >= _maxChildSize - 0.001;

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

    if (velocity > 300) {
      _collapseSheet();
      return;
    }

    if (velocity < -300) {
      _expandSheet();
      return;
    }

    final middleSize = (_minChildSize + _maxChildSize) / 2;

    if (_sheetController.size < middleSize) {
      _collapseSheet();
    } else {
      _expandSheet();
    }
  }

  void _collapsePoiSheet() {
    if (!_poiSheetController.isAttached) return;

    _poiSheetController.animateTo(
      _poiMinChildSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );

    if (_poiSheetScrollController?.hasClients ?? false) {
      _poiSheetScrollController!.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _expandPoiSheet() {
    if (!_poiSheetController.isAttached) return;

    _poiSheetController.animateTo(
      _poiMaxChildSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handlePoiSheetDragUpdate(DragUpdateDetails details) {
    if (!_poiSheetController.isAttached) return;

    final delta = details.primaryDelta ?? 0;
    final minPixels = _poiSheetController.sizeToPixels(_poiMinChildSize);
    final maxPixels = _poiSheetController.sizeToPixels(_poiMaxChildSize);
    final nextPixels = (_poiSheetController.pixels - delta)
        .clamp(minPixels, maxPixels)
        .toDouble();

    _poiSheetController.jumpTo(_poiSheetController.pixelsToSize(nextPixels));
  }

  void _handlePoiSheetDragEnd(DragEndDetails details) {
    if (!_poiSheetController.isAttached) return;

    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      _collapsePoiSheet();
      return;
    }

    if (velocity < -300) {
      _expandPoiSheet();
      return;
    }

    final middleSize = (_poiMinChildSize + _poiMaxChildSize) / 2;

    if (_poiSheetController.size < middleSize) {
      _collapsePoiSheet();
    } else {
      _expandPoiSheet();
    }
  }

  void _onGroupChanged() {
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
    _closeEditor();

    final pointProvider = context.read<PointOfInterestProvider>();

    if (activeGroupId == null) {
      pointProvider.clear();
    } else {
      pointProvider.loadPoints(activeGroupId);
    }

    final locationNotifier = ref.read(locationProvider.notifier);

    if (activeGroupId == null) {
      locationNotifier.stopViewingGroup();
    } else {
      locationNotifier.startViewingGroup(activeGroupId);
    }
  }

  void _startCreate() {
    setState(() {
      _editing = true;
      _editingPoint = null;
      _draftLocation = null;
      _draftRadius = 100;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _expandPoiSheet());
  }

  void _startEdit(PointOfInterest point) {
    setState(() {
      _editing = true;
      _editingPoint = point;
      _draftLocation = LatLng(point.latitude, point.longitude);
      _draftRadius = point.radius;
    });

    _mapController.move(_draftLocation!, 16);
    WidgetsBinding.instance.addPostFrameCallback((_) => _expandPoiSheet());
  }

  void _closeEditor() {
    if (!mounted) {
      return;
    }

    setState(() {
      _editing = false;
      _editingPoint = null;
      _draftLocation = null;
      _draftRadius = 100;
    });
  }

  void _selectPoint(PointOfInterest point) {
    _mapController.move(LatLng(point.latitude, point.longitude), 16);

    _collapseSheet();
  }

  Future<void> _showPointInfo(PointOfInterest point) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                point.description?.isNotEmpty == true
                    ? point.description!
                    : 'Sin descripción',
              ),
              Text('Radio: ${point.radius.toStringAsFixed(0)} m'),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _startEdit(point);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _confirmDelete(point);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar punto de interés'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PointOfInterest point) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este punto de interés?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<PointOfInterestProvider>();

    final success = await provider.delete(point.groupId, point.id);

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Punto de interés eliminado.'
              : provider.errorMessage ?? 'No se pudo eliminar.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupProvider.removeListener(_onGroupChanged);
    _sheetController.dispose();
    _poiSheetController.dispose();

    if (_viewingGroupId != null) {
      ref.read(locationProvider.notifier).stopViewingGroup();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final pointProvider = context.watch<PointOfInterestProvider>();

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) {
          _editorKey.currentState?.requestClose();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    LocationMap(
                      groupId: groupProvider.activeGroup?.id,
                      points: pointProvider.points,
                      previewPoint: _editing ? _draftLocation : null,
                      previewRadius: _editing && _draftLocation != null
                          ? _draftRadius
                          : null,
                      controller: _mapController,
                      onTap: _editing
                          ? (point) {
                              setState(() {
                                _draftLocation = point;
                              });
                            }
                          : null,
                    ),
                    if (groupProvider.groupDetails != null &&
                        _sheetExpanded &&
                        !_editing)
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
              if (groupProvider.groupDetails != null && !_editing)
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
                              child: Column(
                                children: [
                                  if (pointProvider.loading)
                                    const LinearProgressIndicator()
                                  else if (pointProvider.points.isNotEmpty)
                                    SizedBox(
                                      height: 76,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        itemCount: pointProvider.points.length,
                                        itemBuilder: (context, index) {
                                          final point =
                                              pointProvider.points[index];

                                          return Card(
                                            child: InkWell(
                                              onTap: () => _selectPoint(point),
                                              onLongPress: () =>
                                                  _showPointInfo(point),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.place,
                                                      color: AppColors.primary,
                                                    ),
                                                    Text(point.name),
                                                    IconButton(
                                                      tooltip:
                                                          'Ver información',
                                                      onPressed: () =>
                                                          _showPointInfo(point),
                                                      icon: const Icon(
                                                        Icons.info_outline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (_editing)
                Positioned.fill(
                  child: DraggableScrollableSheet(
                    controller: _poiSheetController,
                    initialChildSize: _poiMaxChildSize,
                    minChildSize: _poiMinChildSize,
                    maxChildSize: _poiMaxChildSize,
                    snap: true,
                    snapSizes: const [_poiMinChildSize, _poiMaxChildSize],
                    builder: (context, scrollController) {
                      _poiSheetScrollController = scrollController;

                      return Material(
                        elevation: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: _handlePoiSheetDragUpdate,
                              onVerticalDragEnd: _handlePoiSheetDragEnd,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 8,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.mutedText,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _editingPoint == null
                                          ? 'Creando punto de interés'
                                          : 'Editando punto de interés',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: PointOfInterestEditor(
                                key: _editorKey,
                                scrollController: scrollController,
                                initial: _editingPoint,
                                selectedLocation: _draftLocation,
                                onLocationChanged: (point) {
                                  setState(() {
                                    _draftLocation = point;
                                  });

                                  _mapController.move(point, 16);
                                },
                                onRadiusChanged: (radius) {
                                  setState(() {
                                    _draftRadius = radius;
                                  });
                                },
                                onCreate: (request) async {
                                  final groupId = groupProvider.activeGroup!.id;

                                  final success = await pointProvider.create(
                                    groupId,
                                    request,
                                  );

                                  if (!success) {
                                    throw Exception(
                                      pointProvider.errorMessage ??
                                          'No se pudo registrar '
                                              'el punto de interés.',
                                    );
                                  }

                                  return true;
                                },
                                onUpdate: (request) async {
                                  final point = _editingPoint!;

                                  final success = await pointProvider.update(
                                    point.groupId,
                                    point.id,
                                    request,
                                  );

                                  if (!success) {
                                    throw Exception(
                                      pointProvider.errorMessage ??
                                          'No se pudo actualizar '
                                              'el punto de interés.',
                                    );
                                  }

                                  return true;
                                },
                                onClosed: _closeEditor,
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
        floatingActionButton: groupProvider.activeGroup != null && !_editing
            ? FloatingActionButton(
                onPressed: _startCreate,
                tooltip: 'Agregar punto de interés',
                child: const Icon(Icons.add_location_alt),
              )
            : null,
      ),
    );
  }
}
