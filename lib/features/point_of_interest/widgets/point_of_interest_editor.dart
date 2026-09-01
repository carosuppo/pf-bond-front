import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../location/models/location_permission_status.dart';
import '../../location/services/location_service.dart';
import '../models/geocoding_result.dart';
import '../models/point_of_interest.dart';
import '../models/point_of_interest_request.dart';
import '../services/geocoding_service.dart';

class PointOfInterestEditor extends StatefulWidget {
  final PointOfInterest? initial;
  final LatLng? selectedLocation;
  final ValueChanged<LatLng> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final Future<bool> Function(CreatePointOfInterestRequest request)? onCreate;
  final Future<bool> Function(UpdatePointOfInterestRequest request)? onUpdate;
  final VoidCallback onClosed;

  const PointOfInterestEditor({
    super.key,
    this.initial,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.onRadiusChanged,
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
  bool _searching = false;
  bool _submitting = false;

  bool get _dirty {
    final initial = widget.initial;
    if (initial == null) {
      return _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _radiusController.text != '100' ||
          widget.selectedLocation != null;
    }
    return _nameController.text != initial.name ||
        _descriptionController.text != (initial.description ?? '') ||
        double.tryParse(_radiusController.text) != initial.radius ||
        widget.selectedLocation?.latitude != initial.latitude ||
        widget.selectedLocation?.longitude != initial.longitude;
  }

  @override
  void initState() {
    super.initState();
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
    if (radius != null && radius > 0) widget.onRadiusChanged(radius);
  }

  Future<void> requestClose() async {
    if (_dirty && widget.initial != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar cambios?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar cambios'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    widget.onClosed();
  }

  Future<void> _useCurrentLocation() async {
    final permission = await _locationService.requestForegroundPermission();
    if (permission != LocationPermissionStatus.whileInUse &&
        permission != LocationPermissionStatus.always) {
      _show('Bond necesita permiso de ubicación mientras usás la app.');
      return;
    }
    try {
      final location = await _locationService.getCurrentLocation();
      widget.onLocationChanged(LatLng(location.latitude, location.longitude));
    } catch (_) {
      _show('No se pudo obtener tu ubicación actual.');
    }
  }

  Future<void> _searchAddress() async {
    if (_addressController.text.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _geocodingService.search(_addressController.text);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final location = widget.selectedLocation;
    if (location == null) {
      _show(
        'Seleccioná una ubicación en el mapa, por dirección o usando tu ubicación.',
      );
      return;
    }
    setState(() => _submitting = true);
    final description = _descriptionController.text;
    final radius = double.parse(_radiusController.text);
    final success = widget.initial == null
        ? await widget.onCreate!(
            CreatePointOfInterestRequest(
              name: _nameController.text,
              description: description,
              radius: radius,
              latitude: location.latitude,
              longitude: location.longitude,
            ),
          )
        : await widget.onUpdate!(
            UpdatePointOfInterestRequest(
              name: _nameController.text,
              description: description,
              radius: radius,
              latitude: location.latitude,
              longitude: location.longitude,
            ),
          );
    if (mounted) setState(() => _submitting = false);
    if (success) widget.onClosed();
  }

  void _show(String message) {
    if (!mounted) return;
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresá un nombre.'
                    : null,
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
                  return radius == null || radius <= 0
                      ? 'Ingresá un radio mayor a 0.'
                      : null;
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
              for (final result in _results)
                ListTile(
                  dense: true,
                  title: Text(
                    result.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onLocationChanged(
                      LatLng(result.latitude, result.longitude),
                    );
                    setState(() => _results = []);
                  },
                ),
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
              ),
              Text(
                widget.selectedLocation == null
                    ? 'Tocá el mapa para elegir la ubicación.'
                    : '${widget.selectedLocation!.latitude.toStringAsFixed(5)}, ${widget.selectedLocation!.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: requestClose,
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
