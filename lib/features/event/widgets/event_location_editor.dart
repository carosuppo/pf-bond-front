import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/global_text_field.dart';
import '../../location/models/location_permission_status.dart';
import '../../location/services/location_service.dart';
import '../../location/widgets/location_map.dart';
import '../models/event_model.response.dart';
import '../models/geocoding_result.dart';
import '../providers/event_provider.dart';
import '../services/geocoding_service.dart';

class EventLocationEditor extends StatefulWidget {
  final EventResponseModel event;
  final int groupId;

  const EventLocationEditor({
    super.key,
    required this.event,
    required this.groupId,
  });

  @override
  State<EventLocationEditor> createState() => _EventLocationEditorState();
}

class _EventLocationEditorState extends State<EventLocationEditor> {
  final _addressController = TextEditingController();
  final _locationService = LocationService();
  final _geocodingService = GeocodingService();

  LatLng? _selectedLocation;
  String? _selectedAddress;
  List<GeocodingResult> _results = [];

  bool _searching = false;
  bool _resolvingAddress = false;
  bool _submitting = false;
  int _addressRequestId = 0;

  @override
  void initState() {
    super.initState();

    final location = widget.event.location;

    if (location != null) {
      _selectedLocation = LatLng(location.latitude, location.longitude);
      _resolveAddress(_selectedLocation!);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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

      _selectLocation(LatLng(location.latitude, location.longitude));
    } catch (_) {
      _show('No se pudo obtener tu ubicación actual.');
    }
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();

    if (query.isEmpty) {
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final results = await _geocodingService.search(query);

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

  void _selectLocation(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = null;
      _results = [];
      _resolvingAddress = true;
    });

    _resolveAddress(location);
  }

  void _selectSearchResult(GeocodingResult result) {
    _addressRequestId++;

    setState(() {
      _selectedLocation = LatLng(result.latitude, result.longitude);
      _selectedAddress = result.displayName;
      _results = [];
      _resolvingAddress = false;
    });
  }

  Future<void> _resolveAddress(LatLng location) async {
    final requestId = ++_addressRequestId;

    if (mounted) {
      setState(() {
        _resolvingAddress = true;
      });
    }

    try {
      final result = await _geocodingService.reverse(location);

      if (!mounted || requestId != _addressRequestId) {
        return;
      }

      setState(() {
        _selectedAddress = result.displayName;
        _resolvingAddress = false;
      });
    } catch (_) {
      if (!mounted || requestId != _addressRequestId) {
        return;
      }

      setState(() {
        _resolvingAddress = false;
      });
      _show('No se pudo obtener la dirección de la ubicación seleccionada.');
    }
  }

  Future<void> _submit() async {
    final location = _selectedLocation;

    if (location == null) {
      _show(
        'Seleccioná una ubicación en el mapa, '
        'por dirección o usando tu ubicación.',
      );
      return;
    }

    if (_resolvingAddress) {
      _show('Esperá a que se obtenga la dirección seleccionada.');
      return;
    }

    final selectedAddress = _selectedAddress;

    if (selectedAddress == null || selectedAddress.isEmpty) {
      _show('No se pudo identificar la dirección seleccionada.');
      return;
    }

    final confirmed = await _confirmLocation(selectedAddress);

    if (!confirmed || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _submitting = true;
    });

    try {
      final eventProvider = context.read<EventProvider>();
      final updatedEvent = await eventProvider.setEventLocation(
        groupId: widget.groupId,
        eventId: widget.event.id,
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) {
        return;
      }

      if (updatedEvent == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              eventProvider.errorMessage ??
                  'No se pudo guardar la ubicación del evento.',
            ),
          ),
        );
        return;
      }

      navigator.pop(updatedEvent);
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<bool> _confirmLocation(String address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Confirmar ubicación',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '¿Estás seguro de que querés guardar esta ubicación?',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Dirección seleccionada',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.fieldColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      text: 'Cancelar',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      text: 'Guardar',
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed ?? false;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: widget.event.location == null
                  ? 'Agregar ubicación'
                  : 'Modificar ubicación',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: _buildEditorContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            children: [
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

              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          result.displayName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _selectSearchResult(result);
                        },
                      );
                    },
                  ),
                ),

              TextButton.icon(
                onPressed: _submitting || _resolvingAddress
                    ? null
                    : _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: LocationMap(
                groupId: null,
                showMembers: false,
                previewPoint: _selectedLocation,
                onTap: _selectLocation,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting || _resolvingAddress ? null : _submit,
              child: Text(_submitting ? 'Guardando...' : 'Guardar ubicación'),
            ),
          ),
        ),
      ],
    );
  }
}
