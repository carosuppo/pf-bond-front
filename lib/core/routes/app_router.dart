import 'package:flutter/material.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

import '../../features/group/screens/create_group_screen.dart';
import '../../features/group/screens/groups_screen.dart';

import '../../features/location/models/map_route_arguments.dart';
import '../../features/location/screens/map_screen.dart';

import '../screens/splash_screen.dart';

import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case AppRoutes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      case AppRoutes.groups:
        return MaterialPageRoute(
          builder: (_) => const GroupsScreen(),
          settings: settings,
        );

      case AppRoutes.createGroup:
        return MaterialPageRoute(
          builder: (_) => const CreateGroupScreen(),
          settings: settings,
        );

      case AppRoutes.map:
        final arguments = settings.arguments;

        return MaterialPageRoute(
          builder: (_) => MapScreen(
            arguments: arguments is MapRouteArguments
                ? arguments
                : null,
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
