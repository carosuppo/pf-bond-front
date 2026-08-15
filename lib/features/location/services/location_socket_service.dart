import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/session_storage_service.dart';

import '../constants/location_tracking_config.dart';
import '../models/location_socket_event.dart';
import '../models/member_location_model.dart';

class LocationSocketService {
  final SessionStorageService _sessionStorage;

  final StreamController<LocationSocketEvent>
      _events =
      StreamController<LocationSocketEvent>
          .broadcast();

  WebSocketChannel? _channel;

  StreamSubscription<Object?>?
      _subscription;

  Timer? _reconnectTimer;

  int? _groupId;

  bool _closedByUser = false;

  LocationSocketService(
    this._sessionStorage,
  );

  Stream<LocationSocketEvent>
      get events =>
          _events.stream;

  Future<void> connect(
    int groupId,
  ) async {
    await disconnect();

    _closedByUser = false;
    _groupId = groupId;

    await _open();
  }

  Future<void> _open() async {
    final token =
        await _sessionStorage
            .getSessionToken();

    if (
        token == null ||
        token.isEmpty ||
        _groupId == null ||
        _closedByUser) {
      return;
    }

    final baseUri =
        Uri.parse(
      ApiConfig.baseUrl,
    );

    final uri =
        baseUri.replace(
      scheme:
          baseUri.scheme == 'https'
              ? 'wss'
              : 'ws',

      path:
          '/location/ws',

      query: null,
    );

    final channel =
        WebSocketChannel.connect(
      uri,
    );

    _channel = channel;

    _subscription =
        channel.stream.listen(
      _handleMessage,

      onError: (_) =>
          _scheduleReconnect(),

      onDone:
          _scheduleReconnect,

      cancelOnError: true,
    );

    channel.sink.add(
      jsonEncode(
        <String, Object>{
          'event':
              'authenticate',

          'data':
              <String, String>{
            'sessionToken':
                token,
          },
        },
      ),
    );
  }

  void _handleMessage(
    Object? rawMessage,
  ) {
    if (rawMessage is! String) {
      return;
    }

    final decoded =
        jsonDecode(
      rawMessage,
    );

    if (decoded is! Map) {
      return;
    }

    final message =
        Map<String, dynamic>.from(
      decoded,
    );

    final event =
        message['event'];

    final rawData =
        message['data'];

    if (
        event is! String ||
        rawData is! Map) {
      return;
    }

    final data =
        Map<String, dynamic>.from(
      rawData,
    );

    if (
        event ==
        'authenticated') {
      _events.add(
        const LocationSocketAuthenticated(),
      );

      _channel?.sink.add(
        jsonEncode(
          <String, Object>{
            'event':
                'subscribeGroup',

            'data':
                <String, int>{
              'groupId':
                  _groupId!,
            },
          },
        ),
      );

      return;
    }

    if (
        event ==
        'authenticationFailed') {
      _closedByUser = true;

      _reconnectTimer
          ?.cancel();

      _reconnectTimer = null;

      _channel
          ?.sink
          .close();

      return;
    }

    if (
        event ==
        'memberLocationUpdated') {
      _events.add(
        MemberLocationUpdated(
          groupId:
              data['groupId']
                  as int,

          member:
              MemberLocationModel.fromJson(
            data,
          ),
        ),
      );

      return;
    }

    if (
        event ==
        'memberLocationRemoved') {
      _events.add(
        MemberLocationRemoved(
          groupId:
              data['groupId']
                  as int,

          memberId:
              data['memberId']
                  as int,

          userId:
              data['userId']
                  as int,
        ),
      );

      return;
    }

    if (
        event ==
        'memberLocationHeartbeat') {
      _events.add(
        MemberLocationHeartbeat(
          groupId:
              data['groupId']
                  as int,

          memberId:
              data['memberId']
                  as int,

          userId:
              data['userId']
                  as int,

          lastSeenAt:
              DateTime.parse(
            data['lastSeenAt']
                as String,
          ),
        ),
      );
    }
  }

  void _scheduleReconnect() {
    if (
        _closedByUser ||
        _groupId == null ||
        _reconnectTimer
                ?.isActive ==
            true) {
      return;
    }

    _reconnectTimer =
        Timer(
      LocationTrackingConfig
          .reconnectDelay,

      _open,
    );
  }

  Future<void>
  disconnect() async {
    _closedByUser = true;
    _groupId = null;

    _reconnectTimer
        ?.cancel();

    _reconnectTimer = null;

    await _subscription
        ?.cancel();

    await _channel
        ?.sink
        .close();

    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();

    await _events.close();
  }
}
