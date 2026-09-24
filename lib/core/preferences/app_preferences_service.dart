import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPreferencesService {
  static const String _activeGroupIdKey = 'active_group_id';
  static const String _pendingInvitationCodeKey = 'pending_invitation_code';

  static const String _locationPermissionStatusKey =
      'location_permission_status';
  static const String _notificationPermissionRequestedKey =
      'notification_permission_requested';

  final FlutterSecureStorage _storage;
  Future<void> _pendingInvitationWrite = Future<void>.value();

  AppPreferencesService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveActiveGroupId(int groupId) async {
    await _storage.write(key: _activeGroupIdKey, value: groupId.toString());
  }

  Future<int?> getActiveGroupId() async {
    final value = await _storage.read(key: _activeGroupIdKey);

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }

  Future<void> clearActiveGroupId() async {
    await _storage.delete(key: _activeGroupIdKey);
  }

  Future<void> savePendingInvitationCode(String invitationCode) {
    final operation = _pendingInvitationWrite.then(
      (_) =>
          _storage.write(key: _pendingInvitationCodeKey, value: invitationCode),
    );
    _pendingInvitationWrite = operation.catchError((Object _) {});
    return operation;
  }

  Future<String?> getPendingInvitationCode() async {
    await _pendingInvitationWrite;
    return _storage.read(key: _pendingInvitationCodeKey);
  }

  Future<bool> clearPendingInvitationCode({String? expectedCode}) {
    late final Future<bool> operation;
    operation = _pendingInvitationWrite.then((_) async {
      if (expectedCode != null) {
        final currentCode = await _storage.read(key: _pendingInvitationCodeKey);
        if (currentCode != expectedCode) {
          return false;
        }
      }

      await _storage.delete(key: _pendingInvitationCodeKey);
      return true;
    });
    _pendingInvitationWrite = operation
        .then<void>((_) {})
        .catchError((Object _) {});
    return operation;
  }

  Future<void> saveLocationPermissionStatus(String status) async {
    await _storage.write(key: _locationPermissionStatusKey, value: status);
  }

  Future<String?> getLocationPermissionStatus() async {
    return _storage.read(key: _locationPermissionStatusKey);
  }

  Future<bool> wasNotificationPermissionRequested() async {
    return await _storage.read(key: _notificationPermissionRequestedKey) ==
        'true';
  }

  Future<void> markNotificationPermissionRequested() async {
    await _storage.write(
      key: _notificationPermissionRequestedKey,
      value: 'true',
    );
  }
}
