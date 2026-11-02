import 'package:flutter/foundation.dart';

import 'app_link_config.dart';

class ApiConfig {
  static const String productionBaseUrl = 'https://srv2008002.hstgr.cloud';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String cartoApiKey = String.fromEnvironment('CARTO_API_KEY');

  static String get baseUrl {
    final configuredBaseUrl = _configuredBaseUrl.trim();

    if (kReleaseMode) {
      validateProductionBaseUrl(configuredBaseUrl);
      return configuredBaseUrl;
    }

    if (configuredBaseUrl.isEmpty) return 'http://10.0.2.2:3000';

    validateDevelopmentBaseUrl(configuredBaseUrl);
    return configuredBaseUrl;
  }

  static void validateStartup() {
    if (!kReleaseMode) return;

    validateProductionBaseUrl(_configuredBaseUrl.trim());
    if (cartoApiKey.trim().isEmpty) {
      throw StateError('La compilación de producción requiere CARTO_API_KEY.');
    }
  }

  static void validateProductionBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (value != productionBaseUrl ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'srv2008002.hstgr.cloud' ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError(
        'La compilación de producción requiere API_BASE_URL=$productionBaseUrl.',
      );
    }
  }

  static void validateDevelopmentBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('API_BASE_URL debe ser una URL HTTP o HTTPS válida.');
    }
  }

  static Uri get privacyPolicyUri => Uri.parse(
    baseUrl,
  ).replace(path: '/legal/privacy/', query: null, fragment: null);

  static Uri get termsOfUseUri => Uri.parse(
    baseUrl,
  ).replace(path: '/legal/terms/', query: null, fragment: null);

  static Uri invitationUri(String normalizedCode, {String? baseUrlOverride}) {
    final apiUri = Uri.parse(baseUrlOverride ?? baseUrl);
    final basePathSegments = apiUri.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );

    return apiUri.replace(
      pathSegments: [...basePathSegments, AppLinkConfig.host, normalizedCode],
      query: null,
      fragment: null,
    );
  }
}
