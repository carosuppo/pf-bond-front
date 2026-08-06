import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../storage/session_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
