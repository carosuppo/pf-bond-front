class AppLinkConfig {
  const AppLinkConfig._();

  static const String scheme = 'https';
  static const String host = 'bond.app';
  static const String invitationPath = 'invite';

  static Uri invitationUri(String normalizedCode) {
    return Uri(
      scheme: scheme,
      host: host,
      pathSegments: [invitationPath, normalizedCode],
    );
  }
}
