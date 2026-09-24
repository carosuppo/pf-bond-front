import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/preferences/app_preferences_service.dart';
import '../models/push_notification_data.dart';
import 'notification_api_service.dart';

const _androidChannel = AndroidNotificationChannel(
  'bond_default',
  'Notificaciones de Bond',
  description: 'Notificaciones generales de Bond.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  final NotificationApiService _notificationApiService;
  final AppPreferencesService _preferencesService;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Future<void> Function(PushNotificationData data)? onOpened;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;
  bool _authenticated = false;

  PushNotificationService(
    this._notificationApiService,
    this._preferencesService, {
    FlutterLocalNotificationsPlugin? localNotifications,
    this.onOpened,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  Future<void> onAuthenticated() async {
    _authenticated = true;

    try {
      await _initialize();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _notificationApiService.registerDeviceToken(token);
      }
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo para push: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _notificationApiService.unregisterDeviceToken(token);
      }
    } catch (error) {
      debugPrint('No se pudo desregistrar el dispositivo para push: $error');
    }
  }

  void onLoggedOut() {
    _authenticated = false;
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          _handleOpenedData(PushNotificationData.fromMap(decoded));
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    if (!await _preferencesService.wasNotificationPermissionRequested()) {
      await FirebaseMessaging.instance.requestPermission();
      await _preferencesService.markNotificationPermissionRequested();
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) =>
          _handleOpenedData(PushNotificationData.fromMap(message.data)),
    );
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) async {
          if (!_authenticated) return;
          try {
            await _notificationApiService.registerDeviceToken(token);
          } catch (error) {
            debugPrint('No se pudo actualizar el token push: $error');
          }
        });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedData(PushNotificationData.fromMap(initialMessage.data));
    }

    _initialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bond_default',
          'Notificaciones de Bond',
          channelDescription: 'Notificaciones generales de Bond.',
          icon: 'ic_notification',
          color: Color(0xFFFFFFFF),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<AuthorizationStatus> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus;
  }

  void _handleOpenedData(PushNotificationData data) {
    if (data.type.isEmpty) return;
    debugPrint('Notificación abierta: ${data.type}');
    final handler = onOpened;
    if (handler != null) {
      unawaited(handler(data));
    }
  }

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
  }
}
