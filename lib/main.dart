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
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/group/providers/group_provider.dart';
import 'features/group/services/group_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

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
        provider.Provider<ApiClient>(
          create: (context) => ApiClient(context.read<SessionStorageService>()),
        ),
        provider.Provider<AuthService>(
          create: (context) => AuthService(
            context.read<ApiClient>(),
            context.read<SessionStorageService>(),
          ),
        ),
        provider.ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthService>()),
        ),
        provider.Provider<GroupService>(
          create: (context) => GroupService(context.read<ApiClient>()),
        ),
        provider.ChangeNotifierProvider<GroupProvider>(
          create: (context) => GroupProvider(
            context.read<GroupService>(),
            context.read<AppPreferencesService>(),
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
