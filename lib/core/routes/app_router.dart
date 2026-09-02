import 'package:flutter/material.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/group/models/get_group_model.response.dart';
import '../../features/group/screens/create_group_screen.dart';
import '../../features/group/screens/edit_group_screen.dart';
import '../../features/group/screens/groups_screen.dart';
import '../../features/group/screens/join_group_screen.dart';
import '../../features/location/screens/map_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
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

      case AppRoutes.map:
        return MaterialPageRoute(
          builder: (_) => const MapScreen(),
          settings: settings,
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case AppRoutes.editProfile:
        return MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
          settings: settings,
        );

      case AppRoutes.joinGroup:
        return MaterialPageRoute(
          builder: (_) => const JoinGroupScreen(),
          settings: settings,
        );

      case AppRoutes.createGroup:
        return MaterialPageRoute(
          builder: (_) => const CreateGroupScreen(),
          settings: settings,
        );

      case AppRoutes.updateGroup:
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => EditGroupScreen(
            group: args['group'] as GetGroupResponseModel,
            isCurrentUserAdmin: args['isCurrentUserAdmin'] as bool,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
