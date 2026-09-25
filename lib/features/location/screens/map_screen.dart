import 'dart:async';

import 'package:bond_front/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_member_info_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../../group/services/group_service.dart';
import '../../group/widgets/group_selector_button.dart';
import '../../point_of_interest/models/point_of_interest.dart';
import '../../point_of_interest/models/point_of_interest_color.dart';
import '../../point_of_interest/providers/point_of_interest_provider.dart';
import '../../point_of_interest/services/point_of_interest_realtime_sync.dart';
import '../../point_of_interest/widgets/point_of_interest_editor.dart';
import '../../routing/models/route_mode.dart';
import '../../routing/providers/navigation_provider.dart';
import '../models/location_socket_event.dart';
import '../providers/location_provider.dart';
import '../widgets/group_info_sheet.dart';
import '../widgets/location_map.dart';
import '../widgets/point_of_interest_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final GroupProvider _groupProvider;
  late final LocationProvider _locationNotifier;
  late final PointOfInterestProvider _pointProvider;
  late final NavigationProvider _navigation;
  late final DraggableScrollableController _sheetController;
  late final DraggableScrollableController _poiSheetController;
  StreamSubscription<LocationSocketEvent>? _groupEventSubscription;

  ScrollController? _sheetScrollController;
  ScrollController? _poiSheetScrollController;

  int? _viewingGroupId;
  bool _sheetExpanded = false;
  bool _pointsExpanded = false;
  int? _selectedMemberId;
  int _memberInfoRequestId = 0;
  bool _memberInfoLoading = false;
  GetMemberInfoResponseModel? _memberInfo;

  final MapController _mapController = MapController();
  final GlobalKey<PointOfInterestEditorState> _editorKey = GlobalKey();

  PointOfInterest? _editingPoint;
  PointOfInterest? _selectedPoint;
  bool _editing = false;
  bool _creatingTemporary = false;
  LatLng? _draftLocation;
  double _draftRadius = 100;
  PointOfInterestColor _draftColor = PointOfInterestColor.blue;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _locationNotifier = ref.read(locationProvider.notifier);
    _pointProvider = context.read<PointOfInterestProvider>();
    _navigation = context.read<NavigationProvider>();
    _groupProvider.addListener(_onGroupChanged);
    _pointProvider.addListener(_onPointsChanged);
    _navigation.addListener(_onNavigationChanged);

    _sheetController = DraggableScrollableController()
      ..addListener(_onSheetSizeChanged);
    _poiSheetController = DraggableScrollableController();

    _groupEventSubscription = ref
        .read(locationSocketServiceProvider)
        .events
        .listen(_onGroupEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewingGroup());
  }

  void _onGroupEvent(LocationSocketEvent event) {
    if (!mounted) return;

    unawaited(
      refreshPointsForSocketEvent(
        event: event,
        viewingGroupId: _viewingGroupId,
        loadPoints: context.read<PointOfInterestProvider>().loadPoints,
      ),
    );
  }

  void _onSheetSizeChanged() {
    final expanded =
        _sheetController.size >= GroupInfoSheet.maxChildSize - 0.001;

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
      GroupInfoSheet.minChildSize,
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
      GroupInfoSheet.maxChildSize,
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

    final minPixels = _sheetController.sizeToPixels(
      GroupInfoSheet.minChildSize,
    );

    final maxPixels = _sheetController.sizeToPixels(
      GroupInfoSheet.maxChildSize,
    );

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

    final middleSize =
        (GroupInfoSheet.minChildSize + GroupInfoSheet.maxChildSize) / 2;

    if (_sheetController.size < middleSize) {
      _collapseSheet();
    } else {
      _expandSheet();
    }
  }

  void _collapsePoiSheet() {
    if (!_poiSheetController.isAttached) return;

    _poiSheetController.animateTo(
      PointOfInterestSheet.minChildSize,
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
      PointOfInterestSheet.maxChildSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handlePoiSheetDragUpdate(DragUpdateDetails details) {
    if (!_poiSheetController.isAttached) return;

    final delta = details.primaryDelta ?? 0;
    final minPixels = _poiSheetController.sizeToPixels(
      PointOfInterestSheet.minChildSize,
    );
    final maxPixels = _poiSheetController.sizeToPixels(
      PointOfInterestSheet.maxChildSize,
    );
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

    final middleSize =
        (PointOfInterestSheet.minChildSize +
            PointOfInterestSheet.maxChildSize) /
        2;

    if (_poiSheetController.size < middleSize) {
      _collapsePoiSheet();
    } else {
      _expandPoiSheet();
    }
  }

  void _onGroupChanged() {
    final activeGroupId = _groupProvider.activeGroup?.id;

    if (activeGroupId != _viewingGroupId) {
      _clearMemberInfo();
      _selectedPoint = null;
      unawaited(_navigation.handleActiveGroupChanged(activeGroupId));
    }

    _syncViewingGroup();
  }

  void _onPointsChanged() {
    final selected = _selectedPoint;
    if (!_pointProvider.loading &&
        selected != null &&
        !_pointProvider.points.any((point) => point.id == selected.id)) {
      if (mounted) setState(() => _selectedPoint = null);
    }
    final targetPointId = _navigation.targetPointId;
    final targetGroupId = _navigation.targetGroupId;
    if (_pointProvider.loading ||
        targetPointId == null ||
        targetGroupId == null) {
      return;
    }
    if (targetGroupId != _groupProvider.activeGroup?.id) return;

    PointOfInterest? updatedDestination;
    for (final point in _pointProvider.points) {
      if (point.id == targetPointId && point.groupId == targetGroupId) {
        updatedDestination = point;
        break;
      }
    }

    if (updatedDestination == null) {
      unawaited(_navigation.handleDestinationUnavailable());
    } else {
      unawaited(_navigation.handleDestinationUpdated(updatedDestination));
    }
  }

  void _onNavigationChanged() {
    final notice = _navigation.takeNotice();
    if (notice == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    });
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

  void _startCreate({bool temporary = false}) {
    if (_navigation.active) return;
    setState(() {
      _editing = true;
      _editingPoint = null;
      _creatingTemporary = temporary;
      _selectedPoint = null;
      _draftLocation = null;
      _draftRadius = 100;
      _draftColor = PointOfInterestColor.blue;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _expandPoiSheet());
  }

  void _startEdit(PointOfInterest point) {
    if (_navigation.active) return;
    setState(() {
      _editing = true;
      _editingPoint = point;
      _creatingTemporary = false;
      _draftLocation = LatLng(point.latitude, point.longitude);
      _draftRadius = point.radius;
      _draftColor = point.color;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _expandPoiSheet());
  }

  void _closeEditor() {
    if (!mounted) {
      return;
    }

    setState(() {
      _editing = false;
      _editingPoint = null;
      _creatingTemporary = false;
      _draftLocation = null;
      _draftRadius = 100;
      _draftColor = PointOfInterestColor.blue;
    });
  }

  void _selectPoint(PointOfInterest point) {
    if (_navigation.active) return;
    setState(() => _selectedPoint = point);
    _mapController.move(LatLng(point.latitude, point.longitude), 16);

    _collapseSheet();
  }

  Future<void> _chooseCreationType() async {
    if (_navigation.active) return;
    final temporary = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Punto de interés permanente'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.timer_rounded),
              title: const Text('Punto de encuentro temporal'),
              subtitle: const Text('Se retirará del mapa al vencer.'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || temporary == null || _navigation.active) return;
    _startCreate(temporary: temporary);
  }

  Future<void> _startNavigation(PointOfInterest point) async {
    if (_navigation.active) return;
    final selectedMode = await showDialog<RouteMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Cómo llegar'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, RouteMode.driving),
            child: const ListTile(
              leading: Icon(Icons.directions_car_rounded),
              title: Text('Auto'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, RouteMode.walking),
            child: const ListTile(
              leading: Icon(Icons.directions_walk_rounded),
              title: Text('Caminando'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || selectedMode == null || _navigation.active) return;

    final success = await _navigation.start(
      point: point,
      selectedMode: selectedMode,
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _navigation.errorMessage ?? 'No se pudo calcular la ruta.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(PointOfInterest point) async {
    if (_navigation.active) return;
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

    if (confirmed != true || !mounted || _navigation.active) {
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
    _pointProvider.removeListener(_onPointsChanged);
    _navigation.removeListener(_onNavigationChanged);
    unawaited(_groupEventSubscription?.cancel());
    _sheetController.dispose();
    _poiSheetController.dispose();

    if (_viewingGroupId != null) {
      unawaited(_locationNotifier.stopViewingGroup());
    }
    unawaited(_navigation.cancel());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final pointProvider = context.watch<PointOfInterestProvider>();
    final authProvider = context.watch<AuthProvider>();
    final navigation = context.watch<NavigationProvider>();
    final topPadding = MediaQuery.paddingOf(context).top;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final routeSheetFraction = groupProvider.groupDetails == null
        ? 0.0
        : _sheetController.isAttached
        ? _sheetController.size
        : (_sheetExpanded
              ? GroupInfoSheet.maxChildSize
              : GroupInfoSheet.minChildSize);
    final routeBottomPadding = groupProvider.groupDetails == null
        ? 32.0
        : screenHeight * routeSheetFraction + 32;
    final navigationOverlayTop = topPadding + 72;

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) {
          _editorKey.currentState?.requestClose();
        }
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                  ),
                  child: Stack(
                    children: [
                      LocationMap(
                        groupId: groupProvider.activeGroup?.id,
                        ownProfilePhoto:
                            authProvider.authResponse?.user.profilePhoto,
                        ownProfileName: authProvider.authResponse?.user.name,
                        points: pointProvider.points,
                        previewColor: _draftColor,
                        previewPoint: _editing ? _draftLocation : null,
                        previewRadius: _editing && _draftLocation != null
                            ? _draftRadius
                            : null,
                        showOffscreenPoints: _pointsExpanded,
                        routePoints: navigation.remainingPoints,
                        routeFitRevision: navigation.routeRevision,
                        routeFitPadding: EdgeInsets.fromLTRB(
                          48,
                          topPadding + 220,
                          48,
                          routeBottomPadding,
                        ),
                        navigationLocation: navigation.currentLocation,
                        destinationPointId: navigation.destination?.id,
                        onPointTap: _editing || navigation.active
                            ? null
                            : _selectPoint,
                        indicatorBottomFraction: _editing
                            ? PointOfInterestSheet.maxChildSize
                            : groupProvider.groupDetails == null
                            ? 0
                            : _sheetExpanded
                            ? GroupInfoSheet.maxChildSize
                            : GroupInfoSheet.minChildSize,
                        controller: _mapController,
                        onMapTap: _editing ? null : _handleMapTap,
                        onMemberTap: _editing ? null : _handleMemberTap,
                        onTap: _editing
                            ? (point) {
                                setState(() {
                                  _draftLocation = point;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 12,
                left: 0,
                right: 0,
                child: const GroupSelectorButton(),
              ),
              if (!_editing && navigation.active)
                Positioned(
                  top: navigationOverlayTop,
                  left: 16,
                  right: 16,
                  child: _NavigationCard(
                    navigation: navigation,
                    onFinish: () => unawaited(navigation.cancel()),
                  ),
                )
              else if (!_editing && _selectedPoint != null)
                Positioned(
                  top: navigationOverlayTop,
                  left: 24,
                  right: 24,
                  child: _SelectedPointCard(
                    point: _selectedPoint!,
                    onDirections: () => _startNavigation(_selectedPoint!),
                    onClose: () => setState(() => _selectedPoint = null),
                  ),
                ),
              if (groupProvider.groupDetails != null && !_editing)
                GroupInfoSheet(
                  controller: _sheetController,
                  group: groupProvider.groupDetails!,
                  memberInfo: _memberInfo,
                  memberInfoLoading: _memberInfoLoading,
                  pointsContent: _buildPointOfInterestContent(
                    pointProvider,
                    navigationActive: navigation.active,
                  ),
                  pointsCount: pointProvider.points.length,
                  onScrollControllerChanged: (controller) {
                    _sheetScrollController = controller;
                  },
                  onDragUpdate: _handleSheetDragUpdate,
                  onDragEnd: _handleSheetDragEnd,
                  onPointsSectionChanged: (visible) {
                    if (_pointsExpanded == visible) {
                      return;
                    }

                    setState(() {
                      _pointsExpanded = visible;
                    });
                  },
                ),
              if (_editing)
                PointOfInterestSheet(
                  controller: _poiSheetController,
                  editorKey: _editorKey,
                  editingPoint: _editingPoint,
                  draftLocation: _draftLocation,
                  draftRadius: _draftRadius,
                  draftColor: _draftColor,
                  createTemporary: _creatingTemporary,
                  title: _editingPoint == null
                      ? _creatingTemporary
                            ? 'Crear punto de encuentro'
                            : 'Crear punto de interés'
                      : 'Editando punto de interés',
                  onScrollControllerChanged: (controller) {
                    _poiSheetScrollController = controller;
                  },
                  onDragUpdate: _handlePoiSheetDragUpdate,
                  onDragEnd: _handlePoiSheetDragEnd,
                  onLocationChanged: (point) {
                    setState(() {
                      _draftLocation = point;
                    });

                    _mapController.move(point, 16);
                  },
                  onColorChanged: (color) =>
                      setState(() => _draftColor = color),
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
                            'No se pudo registrar el punto de interés.',
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
                            'No se pudo actualizar el punto de interés.',
                      );
                    }

                    return true;
                  },
                  onClosed: _closeEditor,
                ),
            ],
          ),
        ),
        floatingActionButton:
            groupProvider.activeGroup != null && !_editing && !navigation.active
            ? FloatingActionButton(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                highlightElevation: 12,
                onPressed: _chooseCreationType,
                tooltip: 'Agregar punto de interés',
                child: const Icon(Icons.add_location_alt_rounded),
              )
            : null,
      ),
    );
  }

  Widget _buildPointOfInterestContent(
    PointOfInterestProvider pointProvider, {
    required bool navigationActive,
  }) {
    return ListTileTheme.merge(
      minLeadingWidth: 22,
      horizontalTitleGap: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pointProvider.loading) const LinearProgressIndicator(),
          if (!pointProvider.loading && pointProvider.points.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  int index = 0;
                  index < pointProvider.points.length;
                  index++
                ) ...[
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    alignment: Alignment.center,
                    child: _PointOfInterestListItem(
                      point: pointProvider.points[index],
                      navigationActive: navigationActive,
                      onTap: _selectPoint,
                      onEdit: _startEdit,
                      onDelete: (point) {
                        unawaited(_confirmDelete(point));
                      },
                      onDirections: (point) {
                        unawaited(_startNavigation(point));
                      },
                    ),
                  ),
                  if (index < pointProvider.points.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PointOfInterestListItem extends StatelessWidget {
  final PointOfInterest point;
  final bool navigationActive;
  final ValueChanged<PointOfInterest> onTap;
  final ValueChanged<PointOfInterest> onEdit;
  final ValueChanged<PointOfInterest> onDelete;
  final ValueChanged<PointOfInterest> onDirections;

  const _PointOfInterestListItem({
    required this.point,
    required this.navigationActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final description = point.description?.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: navigationActive ? null : () => onTap(point),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!navigationActive)
                    Transform.translate(
                      offset: const Offset(-6, -6),
                      child: IconButton(
                        tooltip: 'Editar punto de interés',
                        color: AppColors.primary,
                        onPressed: () => onEdit(point),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      point.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!navigationActive)
                    Transform.translate(
                      offset: const Offset(6, -6),
                      child: IconButton(
                        tooltip: 'Eliminar punto de interés',
                        color: AppColors.primary,
                        onPressed: () => onDelete(point),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                ],
              ),
              Text(
                description == null || description.isEmpty
                    ? 'Sin descripción'
                    : description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
              if (point.isTemporary) ...[
                const SizedBox(height: 4),
                Text(
                  _temporaryLabel(point),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Radio: ${_formatPointRadius(point.radius)} m',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
              if (!navigationActive) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => onDirections(point),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Cómo llegar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPointCard extends StatelessWidget {
  const _SelectedPointCard({
    required this.point,
    required this.onDirections,
    required this.onClose,
  });

  final PointOfInterest point;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              point.isTemporary ? Icons.timer_rounded : Icons.flag_rounded,
              color: point.color.visualColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                point.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Cómo llegar'),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({required this.navigation, required this.onFinish});

  final NavigationProvider navigation;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final point = navigation.destination!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.navigation_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(navigation.mode?.label ?? ''),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatDistance(navigation.remainingDistanceMeters)} restantes'
              ' · ~${_formatDuration(navigation.durationSeconds)}',
            ),
            if (navigation.recalculating) ...[
              const SizedBox(height: 6),
              const Text(
                'Recalculando ruta...',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
            if (navigation.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                navigation.errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onFinish,
              child: const Text('Finalizar ruta'),
            ),
          ],
        ),
      ),
    );
  }
}

String _temporaryLabel(PointOfInterest point) {
  final endTime = point.endTime?.toLocal();
  if (endTime == null) return 'Temporal';
  final hour = endTime.hour.toString().padLeft(2, '0');
  final minute = endTime.minute.toString().padLeft(2, '0');
  return 'Temporal · vence $hour:$minute';
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '$hours h' : '$hours h $remainingMinutes min';
}

String _formatPointRadius(double radius) {
  return radius == radius.roundToDouble()
      ? radius.toInt().toString()
      : radius.toString();
}
