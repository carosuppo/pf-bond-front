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
  bool _editing = false;
  LatLng? _draftLocation;
  double _draftRadius = 100;
  PointOfInterestColor _draftColor = PointOfInterestColor.blue;

  @override
  void initState() {
    super.initState();

    _groupProvider = context.read<GroupProvider>();
    _locationNotifier = ref.read(locationProvider.notifier);
    _groupProvider.addListener(_onGroupChanged);

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
      _draftColor = PointOfInterestColor.blue;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _expandPoiSheet());
  }

  void _startEdit(PointOfInterest point) {
    setState(() {
      _editing = true;
      _editingPoint = point;
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
      _draftLocation = null;
      _draftRadius = 100;
      _draftColor = PointOfInterestColor.blue;
    });
  }

  void _selectPoint(PointOfInterest point) {
    _mapController.move(LatLng(point.latitude, point.longitude), 16);

    _collapseSheet();
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
    unawaited(_groupEventSubscription?.cancel());
    _sheetController.dispose();
    _poiSheetController.dispose();

    if (_viewingGroupId != null) {
      unawaited(_locationNotifier.stopViewingGroup());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final pointProvider = context.watch<PointOfInterestProvider>();
    final authProvider = context.watch<AuthProvider>();
    final topPadding = MediaQuery.paddingOf(context).top;

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
              if (groupProvider.groupDetails != null && !_editing)
                GroupInfoSheet(
                  controller: _sheetController,
                  group: groupProvider.groupDetails!,
                  memberInfo: _memberInfo,
                  memberInfoLoading: _memberInfoLoading,
                  pointsContent: _buildPointOfInterestContent(pointProvider),
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
                  title: _editingPoint == null
                      ? 'Creando punto de interés'
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
        floatingActionButton: groupProvider.activeGroup != null && !_editing
            ? FloatingActionButton(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                highlightElevation: 12,
                onPressed: _startCreate,
                tooltip: 'Agregar punto de interés',
                child: const Icon(Icons.add_location_alt_rounded),
              )
            : null,
      ),
    );
  }

  Widget _buildPointOfInterestContent(PointOfInterestProvider pointProvider) {
    return ListTileTheme.merge(
      minLeadingWidth: 22,
      horizontalTitleGap: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pointProvider.loading) const LinearProgressIndicator(),
          if (!pointProvider.loading && pointProvider.points.isNotEmpty)
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
                  onTap: _selectPoint,
                  onEdit: _startEdit,
                  onDelete: (point) {
                    unawaited(_confirmDelete(point));
                  },
                ),
              ),
              if (index < pointProvider.points.length - 1)
                const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _PointOfInterestListItem extends StatelessWidget {
  final PointOfInterest point;
  final ValueChanged<PointOfInterest> onTap;
  final ValueChanged<PointOfInterest> onEdit;
  final ValueChanged<PointOfInterest> onDelete;

  const _PointOfInterestListItem({
    required this.point,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = point.description?.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onTap(point),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
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
              const SizedBox(height: 4),
              Text(
                'Radio: ${_formatPointRadius(point.radius)} m',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPointRadius(double radius) {
  return radius == radius.roundToDouble()
      ? radius.toInt().toString()
      : radius.toString();
}
