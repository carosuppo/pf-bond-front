import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/group_socket_event.dart';
import 'package:bond_front/features/group/services/group_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Storage extends SessionStorageService {
  Completer<String?>? pending;
  @override
  Future<String?> getSessionToken() async =>
      pending == null ? 'opaque' : pending!.future;
}

Future<void> waitFor(bool Function() condition) async {
  for (int i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  late HttpServer server;
  late GroupSocketService socket;
  late _Storage storage;
  late List<WebSocket> peers;
  late List<String> frames;
  late List<GroupSocketEvent> events;
  late StreamSubscription<GroupSocketEvent> subscription;
  late List<Uri> urls;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    storage = _Storage();
    peers = [];
    frames = [];
    events = [];
    urls = [];
    server.listen((HttpRequest request) async {
      final WebSocket peer = await WebSocketTransformer.upgrade(request);
      peers.add(peer);
      peer.listen((Object? frame) {
        if (frame is String) frames.add(frame);
      });
    });
    socket = GroupSocketService(
      storage,
      reconnectDelay: const Duration(milliseconds: 20),
      channelFactory: (Uri uri) {
        urls.add(uri);
        return WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${server.port}/group/ws'),
        );
      },
    );
    subscription = socket.events.listen(events.add);
  });
  tearDown(() async {
    await subscription.cancel();
    await socket.dispose();
    for (final WebSocket peer in peers) {
      await peer.close();
    }
    await server.close(force: true);
  });
  test(
    'authenticates using opaque token and ignores malformed frames',
    () async {
      await socket.connect();
      await waitFor(() => frames.isNotEmpty);
      expect(urls.single.path, '/group/ws');
      expect(jsonDecode(frames.single), {
        'event': 'authenticate',
        'data': {'sessionToken': 'opaque'},
      });
      final WebSocket peer = peers.single;
      for (final String frame in [
        'invalid',
        '[]',
        '{"event":5}',
        '{"event":"groupsChanged","data":{"groupId":1,"reason":"updated"}}',
      ]) {
        peer.add(frame);
      }
      peer.add('{"event":"authenticated","data":{}}');
      peer.add(
        '{"event":"groupsChanged","data":{"groupId":"bad","reason":"updated"}}',
      );
      peer.add(
        '{"event":"groupsChanged","data":{"groupId":1,"reason":"updated"}}',
      );
      await waitFor(() => events.length == 2);
      expect(events.first, isA<GroupSocketAuthenticated>());
      expect((events.last as GroupsChanged).groupId, 1);
    },
  );
  test('unexpected close reconnects and authenticates again', () async {
    await socket.connect();
    await waitFor(() => frames.isNotEmpty);
    await peers.first.close();
    await waitFor(() => frames.length == 2);
    expect(peers.length, 2);
    expect(frames.first, frames.last);
  });
  test('manual close never reconnects', () async {
    await socket.connect();
    await waitFor(() => peers.isNotEmpty);
    await socket.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(peers.length, 1);
  });
  test('authenticationFailed stops reconnect loop', () async {
    await socket.connect();
    await waitFor(() => peers.isNotEmpty);
    peers.single.add('{"event":"authenticationFailed","data":{}}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(peers.length, 1);
    expect(events, isEmpty);
  });
  test('disconnect invalidates pending token retrieval', () async {
    storage.pending = Completer<String?>();
    final Future<void> connection = socket.connect();
    await Future<void>.delayed(Duration.zero);
    await socket.disconnect();
    storage.pending!.complete('old-session');
    await connection;
    expect(peers, isEmpty);
    expect(urls, isEmpty);
  });
}
