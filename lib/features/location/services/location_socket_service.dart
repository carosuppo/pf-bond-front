import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/session_storage_service.dart';

import '../constants/location_tracking_config.dart';
import '../models/location_socket_event.dart';

class LocationSocketService {
  final SessionStorageService _sessionStorage;
  final WebSocketChannel Function(Uri) _channelFactory;

  final StreamController<LocationSocketEvent> _events =
      StreamController<LocationSocketEvent>.broadcast();

  WebSocketChannel? _channel;

  StreamSubscription<Object?>? _subscription;

  Timer? _reconnectTimer;

  int? _groupId;

  bool _closedByUser = false;
  int _connectionVersion = 0;

  LocationSocketService(
    this._sessionStorage, {
    WebSocketChannel Function(Uri)? channelFactory,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  Stream<LocationSocketEvent> get events => _events.stream;

  Future<void> connect(int groupId) async {
    final connectionVersion = ++_connectionVersion;
    _closedByUser = true;
    _groupId = null;
    await _closeCurrentConnection();
    if (_connectionVersion != connectionVersion) return;
    _closedByUser = false;
    _groupId = groupId;

    await _open(connectionVersion);
  }

  Future<void> _open(int connectionVersion) async {
    final token = await _sessionStorage.getSessionToken();

    if (token == null ||
        token.isEmpty ||
        _groupId == null ||
        _closedByUser ||
        _connectionVersion != connectionVersion) {
      return;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);

    final uri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',

      path: '/location/ws',

      query: null,
    );

    final channel = _channelFactory(uri);

    _channel = channel;

    _subscription = channel.stream.listen(
      _handleMessage,

      onError: (_) => _scheduleReconnect(),

      onDone: _scheduleReconnect,

      cancelOnError: true,
    );

    channel.sink.add(
      jsonEncode(<String, Object>{
        'event': 'authenticate',

        'data': <String, String>{'sessionToken': token},
      }),
    );
  }

  void _handleMessage(Object? rawMessage) {
    if (rawMessage is! String) {
      return;
    }

    final decoded = jsonDecode(rawMessage);

    if (decoded is! Map) {
      return;
    }

    final message = Map<String, dynamic>.from(decoded);

    final event = message['event'];

    final rawData = message['data'];

    if (event is! String || rawData is! Map) {
      return;
    }

    final data = Map<String, dynamic>.from(rawData);

    if (event == 'authenticated') {
      _events.add(const LocationSocketAuthenticated());

      _channel?.sink.add(
        jsonEncode(<String, Object>{
          'event': 'subscribeGroup',

          'data': <String, int>{'groupId': _groupId!},
        }),
      );

      return;
    }

    if (event == 'authenticationFailed') {
      _closedByUser = true;

      _reconnectTimer?.cancel();

      _reconnectTimer = null;

      _channel?.sink.close();

      return;
    }

    final socketEvent = parseLocationSocketEvent(event, data);
    if (socketEvent != null) _events.add(socketEvent);
  }

  void _scheduleReconnect() {
    if (_closedByUser ||
        _groupId == null ||
        _reconnectTimer?.isActive == true) {
      return;
    }

    final connectionVersion = _connectionVersion;
    _reconnectTimer = Timer(
      LocationTrackingConfig.reconnectDelay,
      () => _open(connectionVersion),
    );
  }

  Future<void> disconnect() async {
    _connectionVersion++;
    _closedByUser = true;
    _groupId = null;

    await _closeCurrentConnection();
  }

  Future<void> _closeCurrentConnection() async {
    _reconnectTimer?.cancel();

    _reconnectTimer = null;

    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    try {
      await subscription?.cancel();
    } finally {
      await channel?.sink.close();
    }
  }

  Future<void> dispose() async {
    await disconnect();

    await _events.close();
  }
}
