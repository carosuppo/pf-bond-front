import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/group/providers/group_provider.dart';
import '../../features/group/services/group_invitation_coordinator.dart';
import '../../features/location/providers/location_provider.dart';
import '../deep_links/app_link_service.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../routes/navigation/post_auth_navigator.dart';

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
    final verificationToken = await context
        .read<AppLinkService>()
        .takePendingEmailVerificationToken();
    final hasSession = verificationToken == null
        ? await authProvider.restoreSession()
        : await authProvider.completeEmailVerification(
            token: verificationToken,
          );

    if (!mounted) {
      return;
    }

    if (!hasSession) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      if (verificationToken != null) {
        context.read<AppLinkService>().releaseEmailVerificationToken(
          verificationToken,
        );
        AppNavigation.showMessage(
          authProvider.errorMessage ??
              'No se pudo verificar el correo. Intentá abrir el enlace nuevamente.',
        );
      }
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final locationNotifier = ref.read(locationProvider.notifier);

    await const PostAuthNavigator().navigate(
      context: context,
      groupProvider: groupProvider,
      locationNotifier: locationNotifier,
      invitationCoordinator: context.read<GroupInvitationCoordinator>(),
      authProvider: authProvider,
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
