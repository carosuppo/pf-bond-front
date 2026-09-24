import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/geocoding_result.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../../location/models/location_permission_status.dart';
import '../../location/services/location_service.dart';
import '../models/point_of_interest.dart';
import '../models/point_of_interest_color.dart';
import '../models/point_of_interest_request.dart';

class PointOfInterestEditor extends StatefulWidget {
  final PointOfInterest? initial;
  final ScrollController scrollController;
  final LatLng? selectedLocation;
  final ValueChanged<LatLng> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<PointOfInterestColor> onColorChanged;
  final Future<bool> Function(CreatePointOfInterestRequest request)? onCreate;
  final Future<bool> Function(UpdatePointOfInterestRequest request)? onUpdate;
  final VoidCallback onClosed;

  const PointOfInterestEditor({
    super.key,
    this.initial,
    required this.scrollController,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.onRadiusChanged,
    required this.onColorChanged,
    this.onCreate,
    this.onUpdate,
    required this.onClosed,
  });

  @override
  State<PointOfInterestEditor> createState() => PointOfInterestEditorState();
}

class PointOfInterestEditorState extends State<PointOfInterestEditor> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _radiusController;

  final _locationService = LocationService();
  final _geocodingService = GeocodingService();
  final _colorScrollController = ScrollController();

  List<GeocodingResult> _results = [];

  late PointOfInterestColor _color;
  bool _searching = false;
  bool _submitting = false;

  bool get _dirty {
    final initial = widget.initial;
    final hasAddressInput = _addressController.text.trim().isNotEmpty;

    if (initial == null) {
      return _color != PointOfInterestColor.blue ||
          _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _radiusController.text != '100' ||
          widget.selectedLocation != null ||
          hasAddressInput;
    }

    return _color != initial.color ||
        _nameController.text != initial.name ||
        _descriptionController.text != (initial.description ?? '') ||
        double.tryParse(_radiusController.text) != initial.radius ||
        widget.selectedLocation?.latitude != initial.latitude ||
        widget.selectedLocation?.longitude != initial.longitude ||
        hasAddressInput;
  }

  @override
  void initState() {
    super.initState();
    _color = widget.initial?.color ?? PointOfInterestColor.blue;

    _nameController = TextEditingController(text: widget.initial?.name ?? '');

    _descriptionController = TextEditingController(
      text: widget.initial?.description ?? '',
    );

    _radiusController = TextEditingController(
      text: widget.initial?.radius.toString() ?? '100',
    )..addListener(_notifyRadius);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _radiusController.dispose();
    _addressController.dispose();
    _colorScrollController.dispose();

    super.dispose();
  }

  void _scrollColors(int direction) {
    if (!_colorScrollController.hasClients) {
      return;
    }

    final position = _colorScrollController.position;
    final target = (position.pixels + direction * 144).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _colorScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _notifyRadius() {
    final radius = double.tryParse(_radiusController.text);

    if (radius != null && radius > 0) {
      widget.onRadiusChanged(radius);
    }
  }

  Future<void> requestClose() async {
    if (_dirty) {
      final discard = await showDiscardChangesDialog(context);

      if (!mounted || discard != true) {
        return;
      }
    }

    widget.onClosed();
  }

  Future<void> _useCurrentLocation() async {
    final permission = await _locationService.requestForegroundPermission();

    if (!mounted) {
      return;
    }

    if (permission != LocationPermissionStatus.whileInUse &&
        permission != LocationPermissionStatus.always) {
      _show('Bond necesita permiso de ubicación mientras usás la app.');
      return;
    }

    try {
      final location = await _locationService.getCurrentLocation();

      if (!mounted) {
        return;
      }

      widget.onLocationChanged(LatLng(location.latitude, location.longitude));
    } catch (_) {
      _show('No se pudo obtener tu ubicación actual.');
    }
  }

  Future<void> _searchAddress() async {
    if (_addressController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final results = await _geocodingService.search(_addressController.text);

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final location = widget.selectedLocation;

    if (location == null) {
      _show(
        'Seleccioná una ubicación en el mapa, '
        'por dirección o usando tu ubicación.',
      );
      return;
    }

    // Se obtiene antes del await para no buscar ancestros
    // usando un BuildContext después de una operación async.
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _submitting = true;
    });

    final description = _descriptionController.text;
    final radius = double.parse(_radiusController.text);

    bool success = false;
    String? submitError;

    try {
      if (widget.initial == null) {
        success = await widget.onCreate!(
          CreatePointOfInterestRequest(
            color: _color,
            name: _nameController.text,
            description: description,
            radius: radius,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      } else {
        success = await widget.onUpdate!(
          UpdatePointOfInterestRequest(
            color: _color,
            name: _nameController.text,
            description: description,
            radius: radius,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }
    } catch (error) {
      submitError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (submitError != null) {
      messenger.showSnackBar(SnackBar(content: Text(submitError)));
      return;
    }

    if (!success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.initial == null
                ? 'No se pudo registrar el punto de interés.'
                : 'No se pudo actualizar el punto de interés.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.initial == null
              ? 'Punto de interés registrado.'
              : 'Punto de interés actualizado.',
        ),
      ),
    );

    widget.onClosed();
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _color.visualColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _color.label,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _CarouselArrow(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Ver colores anteriores',
                      onTap: () => _scrollColors(-1),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _colorScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            for (
                              int i = 0;
                              i < PointOfInterestColor.values.length;
                              i++
                            ) ...[
                              _ColorSwatch(
                                color:
                                    PointOfInterestColor.values[i].visualColor,
                                label: PointOfInterestColor.values[i].label,
                                selected:
                                    _color == PointOfInterestColor.values[i],
                                enabled: !_submitting,
                                onTap: () {
                                  final color = PointOfInterestColor.values[i];
                                  setState(() => _color = color);
                                  widget.onColorChanged(color);
                                },
                              ),
                              if (i < PointOfInterestColor.values.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _CarouselArrow(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Ver más colores',
                      onTap: () => _scrollColors(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlobalTextField(
                controller: _nameController,
                label: 'Nombre *',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá un nombre.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              GlobalTextField(
                controller: _descriptionController,
                label: 'Descripción opcional',
              ),
              const SizedBox(height: 16),
              GlobalTextField(
                controller: _radiusController,
                label: 'Radio en metros *',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final radius = double.tryParse(value ?? '');

                  if (radius == null || radius <= 0) {
                    return 'Ingresá un radio mayor a 0.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlobalTextField(
                      controller: _addressController,
                      label: 'Dirección',
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                  IconButton(
                    onPressed: _searching ? null : _searchAddress,
                    icon: _searching
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
              for (final result in _results) ...[
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  color: AppColors.cardColor,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () {
                      widget.onLocationChanged(
                        LatLng(result.latitude, result.longitude),
                      );

                      setState(() {
                        _results = [];
                      });
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        result.displayName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
              ),
              Text(
                widget.selectedLocation == null
                    ? 'Tocá el mapa para elegir la ubicación.'
                    : '${widget.selectedLocation!.latitude.toStringAsFixed(5)}, '
                          '${widget.selectedLocation!.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null : requestClose,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting
                          ? 'Guardando...'
                          : widget.initial == null
                          ? 'Registrar'
                          : 'Guardar',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.fieldColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.mutedText, size: 22),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}
