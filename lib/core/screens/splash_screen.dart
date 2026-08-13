import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/location/providers/location_provider.dart';

import '../routes/app_routes.dart';
import '../storage/session_storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _navigate();
    });
  }

  Future<void> _navigate() async {
    final sessionStorage = context.read<SessionStorageService>();

    final hasValidSession = await sessionStorage.hasValidSession();

    if (hasValidSession) {
      await ref.read(locationProvider.notifier).restoreSharingAndTracking();
    }

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacementNamed(hasValidSession ? AppRoutes.map : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}
