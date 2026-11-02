class AppLinkConfig {
  const AppLinkConfig._();

  static const String scheme = 'bond';
  static const String host = 'invite';
  static const String emailVerificationHost = 'verify-email';

  static Uri invitationUri(String normalizedCode) {
    return Uri(scheme: scheme, host: host, pathSegments: [normalizedCode]);
  }
}
