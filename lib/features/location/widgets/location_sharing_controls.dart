import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_permission_status.dart';
import '../providers/location_provider.dart';

/// Permission prompts and settings navigation follow explicit user actions.
class LocationSharingControls extends ConsumerWidget {
  const LocationSharingControls({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationProvider);
    final sharing = state.sharingForGroup(groupId);
    if (sharing == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Compartir mi ubicación'),
          subtitle: Text(
            sharing.shareLocationMandatorily
                ? 'Este grupo requiere compartir ubicación. Podés salir del grupo para dejar de compartir con él.'
                : 'Compartir continuamente con los miembros de este grupo.',
          ),
          value: sharing.effectiveLocationSharing,
          onChanged: state.isLoading || sharing.shareLocationMandatorily
              ? null
              : (enabled) => _changeSharing(context, ref, enabled),
        ),
        if (state.permissionStatus != LocationPermissionStatus.always)
          TextButton(
            onPressed: state.isLoading
                ? null
                : () => _changeSharing(context, ref, true),
            child: const Text('Habilitar ubicación en segundo plano'),
          ),
        if (state.errorMessage != null) Text(state.errorMessage!),
        if (state.permissionStatus == LocationPermissionStatus.whileInUse ||
            state.permissionStatus == LocationPermissionStatus.deniedForever)
          TextButton(
            onPressed: () =>
                ref.read(locationProvider.notifier).openPermissionSettings(),
            child: const Text('Abrir permisos de Bond'),
          ),
        if (state.permissionStatus == LocationPermissionStatus.serviceDisabled)
          TextButton(
            onPressed: () =>
                ref.read(locationProvider.notifier).openGpsSettings(),
            child: const Text('Abrir configuración de ubicación'),
          ),
        if (state.hasEffectiveSharing)
          TextButton.icon(
            icon: const Icon(Icons.battery_saver_outlined),
            label: const Text('Batería y ubicación continua'),
            onPressed: () => _batterySettings(context, ref),
          ),
      ],
    );
  }

  Future<void> _changeSharing(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Compartir ubicación en segundo plano'),
          content: const Text(
            'Bond recopila y envía la ubicación de tu dispositivo a sus servidores para mostrarla a los miembros de los grupos donde activaste compartir. '
            'La precisión depende del permiso de ubicación que elijas. '
            'La ubicación se recopila también en segundo plano, incluso cuando la app está cerrada o no está en uso. '
            'Para compartir continuamente, elegí Permitir siempre en los permisos de ubicación. Podés dejar de compartir desde el grupo; si es obligatorio, podés salir del grupo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) return;
    }
    await ref.read(locationProvider.notifier).setGroupSharing(groupId, enabled);
  }

  Future<void> _batterySettings(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batería y ubicación continua'),
        content: const Text(
          'Android puede limitar la ubicación compartida cuando Bond permanece mucho tiempo sin usarse. Podés revisar manualmente la optimización de batería de Bond. Es opcional y podés seguir usando la app sin cambiarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    await ref.read(locationProvider.notifier).openBatterySettings();
  }
}
