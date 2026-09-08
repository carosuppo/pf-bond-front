import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../location/models/location_permission_status.dart';
import '../../location/services/location_service.dart';
import '../models/geocoding_result.dart';
import '../models/point_of_interest.dart';
import '../models/point_of_interest_color.dart';
import '../models/point_of_interest_request.dart';
import '../services/geocoding_service.dart';

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

  List<GeocodingResult> _results = [];

  late PointOfInterestColor _color;
  bool _searching = false;
  bool _submitting = false;

  bool get _dirty {
    final initial = widget.initial;

    if (initial == null) {
      return _color != PointOfInterestColor.blue ||
          _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _radiusController.text != '100' ||
          widget.selectedLocation != null;
    }

    return _color != initial.color ||
        _nameController.text != initial.name ||
        _descriptionController.text != (initial.description ?? '') ||
        double.tryParse(_radiusController.text) != initial.radius ||
        widget.selectedLocation?.latitude != initial.latitude ||
        widget.selectedLocation?.longitude != initial.longitude;
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

    super.dispose();
  }

  void _notifyRadius() {
    final radius = double.tryParse(_radiusController.text);

    if (radius != null && radius > 0) {
      widget.onRadiusChanged(radius);
    }
  }

  Future<void> requestClose() async {
    if (_dirty && widget.initial != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Descartar cambios?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Descartar cambios'),
            ),
          ],
        ),
      );

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
              Text(
                widget.initial == null
                    ? 'Registrar punto de interés'
                    : 'Editar punto de interés',
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Color'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final color in PointOfInterestColor.values)
                    ChoiceChip(
                      label: Text(color.label),
                      avatar: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.visualColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      selected: _color == color,
                      showCheckmark: true,
                      onSelected: _submitting
                          ? null
                          : (_) {
                              setState(() => _color = color);
                              widget.onColorChanged(color);
                            },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá un nombre.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción opcional',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Radio en metros *',
                ),
                validator: (value) {
                  final radius = double.tryParse(value ?? '');

                  if (radius == null || radius <= 0) {
                    return 'Ingresá un radio mayor a 0.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressController,
                      onSubmitted: (_) => _searchAddress(),
                      decoration: const InputDecoration(labelText: 'Dirección'),
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
                const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
