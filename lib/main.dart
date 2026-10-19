import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import 'core/deep_links/app_link_service.dart';
import 'core/network/api_client.dart';
import 'core/preferences/app_preferences_service.dart';
import 'core/routes/app_navigation.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/navigation/post_auth_navigator.dart';
import 'core/storage/session_storage_service.dart';
import 'core/theme/app_colors.dart';
import 'core/timezone/app_timezone.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_state_cleanup.dart';
import 'features/event/providers/event_provider.dart';
import 'features/event/services/event_reminder_service.dart';
import 'features/event/services/event_service.dart';
import 'features/event/utils/event_reminder_navigation.dart';
import 'features/group/providers/group_provider.dart';
import 'features/group/services/group_invitation_coordinator.dart';
import 'features/group/services/group_invitation_share_service.dart';
import 'features/group/services/group_service.dart';
import 'features/location/providers/location_provider.dart';
import 'features/location/services/background_location_service.dart';
import 'features/location/services/location_service.dart';
import 'features/location/widgets/mandatory_group_location_dialog.dart';
import 'features/notification/models/push_notification_data.dart';
import 'features/notification/providers/group_inbox_provider.dart';
import 'features/notification/services/notification_api_service.dart';
import 'features/notification/services/push_notification_service.dart';
import 'features/point_of_interest/providers/point_of_interest_provider.dart';
import 'features/point_of_interest/services/point_of_interest_service.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/services/profile_photo_picker_service.dart';
import 'features/profile/services/profile_service.dart';
import 'features/routing/providers/navigation_provider.dart';
import 'features/routing/services/route_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencesService = AppPreferencesService();
  final appLinkService = AppLinkService(preferencesService);
  await appLinkService.initialize();

  BackgroundLocationService.initialize();

  await dotenv.load(fileName: '.env');

  AppTimezone.initialize();

  runApp(
    ProviderScope(
      child: MyApp(
        preferencesService: preferencesService,
        appLinkService: appLinkService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.preferencesService,
    required this.appLinkService,
  });

  final AppPreferencesService preferencesService;
  final AppLinkService appLinkService;

  @override
  Widget build(BuildContext context) {
    return provider.MultiProvider(
      providers: [
        provider.Provider<SessionStorageService>(
          create: (_) => SessionStorageService(),
        ),
        provider.Provider<AppPreferencesService>.value(
          value: preferencesService,
        ),
        provider.Provider<AppLinkService>.value(value: appLinkService),
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
            onOpened: (data) async {
              if (data.type == 'GROUP_JOIN_REQUEST') {
                AppNavigation.navigatorKey.currentState?.pushNamed(
                  AppRoutes.inbox,
                );
                return;
              }
              if (data.type == 'GROUP_JOIN_REQUEST_ACCEPTED' ||
                  data.type == 'GROUP_JOIN_REQUEST_REJECTED') {
                await _handleGroupJoinRequestResolution(data, openMap: true);
                return;
              }
              if (data.type != 'EVENT_REMINDER') return;
              final groupId = int.tryParse(data.groupId ?? '');
              final eventId = int.tryParse(data.eventId ?? '');
              if (groupId == null || eventId == null) return;
              await handleEventReminderTap(groupId: groupId, eventId: eventId);
            },
            onReceived: (data) async {
              final appContext = AppNavigation.navigatorKey.currentContext;
              if (appContext != null) {
                await appContext.read<GroupInboxProvider>().load();
              }
              if (data.type == 'GROUP_JOIN_REQUEST_ACCEPTED' ||
                  data.type == 'GROUP_JOIN_REQUEST_REJECTED') {
                await _handleGroupJoinRequestResolution(data);
              }
            },
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
        provider.Provider<ProfilePhotoPickerService>(
          create: (_) => ProfilePhotoPickerService(),
        ),
        provider.Provider<GroupService>(
          create: (context) => GroupService(context.read<ApiClient>()),
        ),
        provider.Provider<GroupInvitationShareService>(
          create: (_) => GroupInvitationShareService(),
        ),
        provider.Provider<GroupInvitationCoordinator>(
          create: (context) =>
              GroupInvitationCoordinator(context.read<AppPreferencesService>()),
        ),
        provider.ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(
            context.read<ProfileService>(),
            context.read<GroupService>(),
            context.read<ProfilePhotoPickerService>(),
          ),
        ),
        provider.ChangeNotifierProvider<GroupProvider>(
          create: (context) => GroupProvider(
            context.read<GroupService>(),
            context.read<AppPreferencesService>(),
          ),
        ),
        provider.ChangeNotifierProvider<GroupInboxProvider>(
          create: (context) => GroupInboxProvider(
            context.read<NotificationApiService>(),
            context.read<GroupService>(),
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
        provider.Provider<LocationService>(create: (_) => LocationService()),
        provider.Provider<RouteService>(
          create: (context) => RouteService(context.read<ApiClient>()),
        ),
        provider.ChangeNotifierProvider<NavigationProvider>(
          create: (context) => NavigationProvider(
            context.read<RouteService>(),
            context.read<LocationService>(),
          ),
        ),
        provider.Provider<EventService>(
          create: (context) => EventService(context.read<ApiClient>()),
        ),
        provider.Provider<EventReminderService>(
          create: (context) => EventReminderService(context.read<ApiClient>()),
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
            navigation: context.read<NavigationProvider>(),
          ),
        ),
        provider.ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<AuthService>(),
            context.read<SessionStateCleanup>(),
          ),
        ),
      ],
      child: const _BondMaterialApp(),
    );
  }
}

Future<void> _handleGroupJoinRequestResolution(
  PushNotificationData data, {
  bool openMap = false,
}) async {
  final context = AppNavigation.navigatorKey.currentContext;
  if (context == null) return;

  final accepted = data.type == 'GROUP_JOIN_REQUEST_ACCEPTED';
  if (accepted) {
    final groupId = int.tryParse(data.groupId ?? '');
    if (groupId == null) return;

    final groups = context.read<GroupProvider>();
    final selected = await groups.refreshAndSelectGroup(groupId: groupId);
    if (!context.mounted) return;

    if (selected) {
      final locationContainer = ProviderScope.containerOf(
        context,
        listen: false,
      );
      await locationContainer
          .read(locationProvider.notifier)
          .restoreSharingAndTracking();
      if (!context.mounted) return;
      if (openMap) {
        AppNavigation.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.map,
          (_) => false,
        );
      }
    }
  }

  if (openMap || !accepted) {
    AppNavigation.showMessage(
      accepted
          ? 'Tu solicitud fue aceptada. Ya puedes ingresar al grupo.'
          : 'Tu solicitud para ingresar al grupo fue rechazada.',
    );
  }
}

class _BondMaterialApp extends ConsumerStatefulWidget {
  const _BondMaterialApp();

  @override
  ConsumerState<_BondMaterialApp> createState() => _BondMaterialAppState();
}

class _BondMaterialAppState extends ConsumerState<_BondMaterialApp> {
  StreamSubscription<String>? _invitationSubscription;
  bool _isHandlingInvitation = false;
  bool _handleAgain = false;
  bool _mandatoryGroupLocationHandlersConfigured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _invitationSubscription ??= context
        .read<AppLinkService>()
        .invitationCodes
        .listen(_handleInvitation);

    if (!_mandatoryGroupLocationHandlersConfigured) {
      final groups = context.read<GroupProvider>();
      final locationNotifier = ref.read(locationProvider.notifier);
      locationNotifier.setMandatoryGroupLocationPrompt((groupId) async {
        final dialogContext = AppNavigation.navigatorKey.currentContext;
        if (dialogContext == null) return null;

        String? groupName;
        for (final group in groups.groups) {
          if (group.id == groupId) {
            groupName = group.name;
            break;
          }
        }
        return showMandatoryGroupLocationDialog(
          context: dialogContext,
          groupName: groupName ?? 'este grupo',
        );
      });

      locationNotifier.setMandatoryGroupExitHandler((groupId) async {
        final left = await groups.leaveGroupForLocationPermission(groupId);
        if (!left) {
          AppNavigation.showMessage(
            groups.errorMessage ??
                'No se pudo salir del grupo. Intentá de nuevo.',
          );
        }
        return left;
      });
      _mandatoryGroupLocationHandlersConfigured = true;
    }
  }

  void _handleInvitation(String _) {
    if (_isHandlingInvitation) {
      _handleAgain = true;
      return;
    }

    _processInvitation();
  }

  Future<void> _processInvitation() async {
    _isHandlingInvitation = true;
    try {
      do {
        _handleAgain = false;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;

        final authProvider = context.read<AuthProvider>();
        final navigator = AppNavigation.navigatorKey.currentState;
        if (navigator == null) {
          _handleAgain = true;
          continue;
        }

        if (authProvider.authResponse == null) {
          if (!authProvider.isLoading) {
            navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          }
          continue;
        }

        await const PostAuthNavigator().navigate(
          context: context,
          groupProvider: context.read<GroupProvider>(),
          locationNotifier: ref.read(locationProvider.notifier),
          invitationCoordinator: context.read<GroupInvitationCoordinator>(),
          authProvider: authProvider,
          navigator: navigator,
        );
      } while (_handleAgain && mounted);
    } finally {
      _isHandlingInvitation = false;
    }
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigation.navigatorKey,
      scaffoldMessengerKey: AppNavigation.scaffoldMessengerKey,
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
      builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
