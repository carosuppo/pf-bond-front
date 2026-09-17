import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import 'core/network/api_client.dart';
import 'core/preferences/app_preferences_service.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/session_storage_service.dart';
import 'core/theme/app_colors.dart';
import 'core/timezone/app_timezone.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_state_cleanup.dart';
import 'features/event/providers/event_provider.dart';
import 'features/event/services/event_service.dart';
import 'features/group/providers/group_provider.dart';
import 'features/group/services/group_service.dart';
import 'features/location/services/background_location_service.dart';
import 'features/notification/services/notification_api_service.dart';
import 'features/notification/services/push_notification_service.dart';
import 'features/point_of_interest/providers/point_of_interest_provider.dart';
import 'features/point_of_interest/services/point_of_interest_service.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/services/profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundLocationService.initialize();

  await dotenv.load(fileName: '.env');

  AppTimezone.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.MultiProvider(
      providers: [
        provider.Provider<SessionStorageService>(
          create: (_) => SessionStorageService(),
        ),
        provider.Provider<AppPreferencesService>(
          create: (_) => AppPreferencesService(),
        ),
        provider.Provider<BackgroundLocationService>(
          create: (_) => BackgroundLocationService(),
        ),
        provider.Provider<ApiClient>(
          create: (context) => ApiClient(context.read<SessionStorageService>()),
        ),

        provider.Provider<NotificationApiService>(
          create: (context) =>
              NotificationApiService(context.read<ApiClient>()),
        ),
        provider.Provider<PushNotificationService>(
          create: (context) => PushNotificationService(
            context.read<NotificationApiService>(),
            context.read<AppPreferencesService>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
        provider.Provider<AuthService>(
          create: (context) => AuthService(
            context.read<ApiClient>(),
            context.read<SessionStorageService>(),
            context.read<PushNotificationService>(),
            context.read<BackgroundLocationService>(),
          ),
        ),
        provider.Provider<ProfileService>(
          create: (context) => ProfileService(context.read<ApiClient>()),
        ),
        provider.Provider<GroupService>(
          create: (context) => GroupService(context.read<ApiClient>()),
        ),
        provider.ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(
            context.read<ProfileService>(),
            context.read<GroupService>(),
          ),
        ),
        provider.ChangeNotifierProvider<GroupProvider>(
          create: (context) => GroupProvider(
            context.read<GroupService>(),
            context.read<AppPreferencesService>(),
          ),
        ),
        provider.Provider<PointOfInterestService>(
          create: (context) =>
              PointOfInterestService(context.read<ApiClient>()),
        ),
        provider.ChangeNotifierProvider<PointOfInterestProvider>(
          create: (context) =>
              PointOfInterestProvider(context.read<PointOfInterestService>()),
        ),
        provider.Provider<EventService>(
          create: (context) => EventService(context.read<ApiClient>()),
        ),
        provider.ChangeNotifierProvider<EventProvider>(
          create: (context) => EventProvider(context.read<EventService>()),
        ),
        provider.Provider<SessionStateCleanup>(
          create: (context) => LocalSessionStateCleanup(
            storage: context.read<SessionStorageService>(),
            push: context.read<PushNotificationService>(),
            preferences: context.read<AppPreferencesService>(),
            group: context.read<GroupProvider>(),
            profile: context.read<ProfileProvider>(),
            points: context.read<PointOfInterestProvider>(),
            events: context.read<EventProvider>(),
            locationContainer: ProviderScope.containerOf(
              context,
              listen: false,
            ),
            backgroundLocation: context.read<BackgroundLocationService>(),
          ),
        ),
        provider.ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<AuthService>(),
            context.read<SessionStateCleanup>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Bond',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.background,

          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            error: AppColors.error,
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.text,
          ),

          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: AppColors.hint),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),

          useMaterial3: true,
        ),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
