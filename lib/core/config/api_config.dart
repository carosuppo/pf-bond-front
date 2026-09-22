import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_link_config.dart';

class ApiConfig {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  }

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
