import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/session_storage_service.dart';
import '../models/group_socket_event.dart';

class GroupSocketService {
  GroupSocketService(
    this._storage, {
    WebSocketChannel Function(Uri)? channelFactory,
    this.reconnectDelay = const Duration(seconds: 3),
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final SessionStorageService _storage;
  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration reconnectDelay;
  final StreamController<GroupSocketEvent> _events =
      StreamController<GroupSocketEvent>.broadcast();
  Stream<GroupSocketEvent> get events => _events.stream;
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  Timer? _authenticationTimer;
  int _version = 0;
  bool _closed = true;
  bool _disposed = false;
  bool _authenticated = false;

  Future<void> connect() async {
    if (_disposed) return;
    final int version = ++_version;
    _closed = true;
    await _closeTransport();
    if (version != _version) return;
    _closed = false;
    await _open(version);
  }

  bool _isCurrent(int version) => !_closed && version == _version;

  Future<void> _open(int version) async {
    try {
      final String? token = await _storage.getSessionToken();
      if (!_isCurrent(version) || token == null || token.isEmpty) return;
      final Uri base = Uri.parse(ApiConfig.baseUrl);
      final Uri uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/group/ws',
        query: null,
        fragment: null,
      );
      final WebSocketChannel channel = _channelFactory(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (Object? message) {
          if (_isCurrent(version)) _handleMessage(message);
        },
        onError: (Object error) => _scheduleReconnect(version),
        onDone: () => _scheduleReconnect(version),
        cancelOnError: true,
      );
      await channel.ready.timeout(const Duration(seconds: 15));
      if (!_isCurrent(version)) return;
      channel.sink.add(
        jsonEncode({
          'event': 'authenticate',
          'data': {'sessionToken': token},
        }),
      );
      _authenticationTimer = Timer(
        const Duration(seconds: 15),
        () => _scheduleReconnect(version),
      );
    } catch (_) {
      _scheduleReconnect(version);
    }
  }

  void _handleMessage(Object? raw) {
    if (raw is! String) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return;
      final Object? data = decoded['data'];
      if (data is! Map<String, Object?>) return;
      switch (decoded['event']) {
        case 'authenticated':
          _authenticationTimer?.cancel();
          _authenticated = true;
          _events.add(const GroupSocketAuthenticated());
        case 'authenticationFailed':
          unawaited(disconnect());
        case 'groupsChanged':
          final Object? id = data['groupId'];
          final Object? reason = data['reason'];
          if (_authenticated && id is int && id > 0 && reason is String) {
            _events.add(GroupsChanged(id, reason));
          }
      }
    } on FormatException {
      // A malformed frame must not terminate the event stream.
    }
  }

  void _scheduleReconnect(int version) {
    if (!_isCurrent(version) || _reconnectTimer != null) return;
    _authenticated = false;
    _authenticationTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () async {
      if (!_isCurrent(version)) return;
      final int nextVersion = ++_version;
      await _closeTransport();
      if (_isCurrent(nextVersion)) await _open(nextVersion);
    });
  }

  Future<void> disconnect() async {
    ++_version;
    _closed = true;
    await _closeTransport();
  }

  Future<void> _closeTransport() async {
    _authenticated = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _authenticationTimer?.cancel();
    _authenticationTimer = null;
    final StreamSubscription<Object?>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;
    _subscription = null;
    _channel = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      // Transport may already have failed.
    }
    try {
      await channel?.sink.close();
    } catch (_) {
      // Local state is already invalidated even if closing fails.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _events.close();
  }
}
