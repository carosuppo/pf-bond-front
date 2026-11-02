import 'package:bond_front/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig production URL validation', () {
    test('accepts the configured production HTTPS URL', () {
      expect(
        () => ApiConfig.validateProductionBaseUrl(
          'https://srv2008002.hstgr.cloud',
        ),
        returnsNormally,
      );
    });

    test('rejects HTTP, localhost, paths, and other hosts', () {
      for (final value in [
        'http://srv2008002.hstgr.cloud',
        'http://localhost:3000',
        'https://srv2008002.hstgr.cloud/api',
        'https://other.example.com',
      ]) {
        expect(
          () => ApiConfig.validateProductionBaseUrl(value),
          throwsStateError,
        );
      }
    });
  });
}
