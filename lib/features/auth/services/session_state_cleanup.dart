import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/app_preferences_service.dart';
import '../../../core/storage/session_storage_service.dart';
import '../../event/providers/event_provider.dart';
import '../../group/providers/group_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../location/services/background_location_service.dart';
import '../../notification/services/push_notification_service.dart';
import '../../point_of_interest/providers/point_of_interest_provider.dart';
import '../../profile/providers/profile_provider.dart';

abstract interface class SessionStateCleanup {
  Future<void> clear();
}

class LocalSessionStateCleanup implements SessionStateCleanup {
  LocalSessionStateCleanup({
    required this.storage,
    required this.push,
    required this.preferences,
    required this.group,
    required this.profile,
    required this.points,
    required this.events,
    required this.locationContainer,
    required this.backgroundLocation,
  });

  final SessionStorageService storage;
  final PushNotificationService push;
  final AppPreferencesService preferences;
  final GroupProvider group;
  final ProfileProvider profile;
  final PointOfInterestProvider points;
  final EventProvider events;
  final ProviderContainer locationContainer;
  final BackgroundLocationService backgroundLocation;

  @override
  Future<void> clear() async {
    await _attempt('session storage', storage.clearSession);
    await _attempt('push local', () async => push.onLoggedOut());
    await _attempt('groups', () async => group.resetSessionState());
    await _attempt('profile', () async => profile.resetSessionState());
    await _attempt('POI', () async => points.resetSessionState());
    await _attempt('events', () async => events.resetSessionState());
    await _attempt('active group preference', preferences.clearActiveGroupId);
    await _attempt(
      'location and socket',
      () =>
          locationContainer.read(locationProvider.notifier).resetSessionState(),
    );
    await _attempt('background tracking', backgroundLocation.stop);
  }

  Future<void> _attempt(String step, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('No se pudo limpiar $step al cerrar la sesión: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
