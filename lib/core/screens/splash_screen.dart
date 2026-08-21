import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../routes/app_routes.dart';

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
      await _restoreSessionAndNavigate();
    });
  }

  Future<void> _restoreSessionAndNavigate() async {
    final authProvider = context.read<AuthProvider>();

    final hasSession = await authProvider.restoreSession();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacementNamed(hasSession ? AppRoutes.map : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}
