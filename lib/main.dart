import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'features/group/providers/group_provider.dart';
import 'features/group/screens/create_group_screen.dart';
import 'features/group/services/group_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),

        Provider<GroupService>(
          create: (context) => GroupService(context.read<ApiClient>()),
        ),

        ChangeNotifierProvider<GroupProvider>(
          create: (context) => GroupProvider(context.read<GroupService>()),
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

        home: const CreateGroupScreen(),
      ),
    );
  }
}
