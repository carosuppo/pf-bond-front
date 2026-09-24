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

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreSessionAndNavigate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreSessionAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.restoreSession();

    if (!mounted) {
      return;
    }

    if (!hasSession) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final locationNotifier = ref.read(locationProvider.notifier);

    await const PostAuthNavigator().navigate(
      context: context,
      groupProvider: groupProvider,
      locationNotifier: locationNotifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/logo_bond_splash.png',
              width: 256,
              height: 256,
            ),
          ),
        ),
      ),
    );
  }
}
