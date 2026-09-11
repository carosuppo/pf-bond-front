import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';
import '../services/notification_api_service.dart';

class NotificationPreferencesProvider extends ChangeNotifier {
  final NotificationApiService _service;
  NotificationPreferencesProvider(this._service);
  NotificationPreferences? preferences;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (isLoading || isSaving) return;
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      preferences = await _service.getPreferences();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<bool> _save(
    void Function() apply,
    void Function() rollback,
    Future<void> Function() request,
  ) async {
    if (isLoading || isSaving) return false;
    isSaving = true;
    errorMessage = null;
    apply();
    _notify();
    try {
      await request();
      return true;
    } catch (error) {
      rollback();
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  Future<bool> setGlobal(bool enabled) {
    final data = preferences;
    if (data == null) return Future.value(false);
    final previous = data.enabled;
    return _save(
      () => data.enabled = enabled,
      () => data.enabled = previous,
      () => _service.setGlobalPreference(enabled),
    );
  }

  Future<bool> setGroup(GroupNotificationPreferences group, bool enabled) {
    if (preferences?.enabled != true) return Future.value(false);
    final previous = group.enabled;
    return _save(
      () => group.enabled = enabled,
      () => group.enabled = previous,
      () => _service.setGroupPreference(group.groupId, enabled),
    );
  }

  Future<bool> setType(
    GroupNotificationPreferences group,
    String type,
    bool enabled,
  ) {
    if (preferences?.enabled != true || !group.enabled) {
      return Future.value(false);
    }
    final previous = group.types[type] ?? true;
    return _save(
      () => group.types[type] = enabled,
      () => group.types[type] = previous,
      () => _service.setTypePreference(group.groupId, type, enabled),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
