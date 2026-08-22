import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../core/routes/navigation/post_auth_navigator.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/group/providers/group_provider.dart';
import '../../features/location/providers/location_provider.dart';
import '../routes/app_routes.dart';

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
      await _restoreSessionAndNavigate();
    });
  }

  Future<void> _restoreSessionAndNavigate() async {
    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.restoreSession();

    if (!mounted) {
      return;
    }

    if (!hasSession) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    await const PostAuthNavigator().navigate(
      context: context,
      groupProvider: context.read<GroupProvider>(),
      locationNotifier: ref.read(locationProvider.notifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}
