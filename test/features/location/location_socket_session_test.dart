import 'dart:async';

import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/location/services/location_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _BlockingStorage extends SessionStorageService {
  final requested = Completer<void>();
  final token = Completer<String?>();

  @override
  Future<String?> getSessionToken() {
    requested.complete();
    return token.future;
  }
}

void main() {
  test(
    'disconnect invalida un connect pendiente antes de abrir el socket',
    () async {
      final storage = _BlockingStorage();
      var opened = 0;
      final socket = LocationSocketService(
        storage,
        channelFactory: (uri) {
          opened++;
          throw StateError('No debe abrirse el socket de la sesión anterior');
        },
      );
      final connection = socket.connect(10);
      await storage.requested.future;
      await socket.disconnect();
      storage.token.complete('token-anterior');
      await connection;
      expect(opened, 0);
      await socket.dispose();
    },
  );
}
