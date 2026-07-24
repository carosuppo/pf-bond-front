import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/location_provider.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de ubicación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inicializando: ${locationState.isLoading}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Permiso: ${locationState.permissionStatus.name}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            if (locationState.currentLocation != null) ...[
              Text(
                'Latitud: ${locationState.currentLocation!.latitude}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Longitud: ${locationState.currentLocation!.longitude}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Precisión: ${locationState.currentLocation!.accuracy} m',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Timestamp: ${locationState.currentLocation!.timestamp}',
                style: const TextStyle(fontSize: 18),
              ),
            ] else
              const Text(
                'Sin ubicación disponible.',
                style: TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(locationProvider.notifier).initialize();
                },
                child: const Text('Volver a inicializar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
