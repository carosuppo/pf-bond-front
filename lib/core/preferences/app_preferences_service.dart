import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPreferencesService {
  static const String _activeGroupIdKey = 'active_group_id';

  final FlutterSecureStorage _storage;

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
}
