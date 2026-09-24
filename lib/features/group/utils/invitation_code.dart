class InvitationCode {
  const InvitationCode._();

  static final RegExp _validPattern = RegExp(r'^[A-Z0-9]{6}$');

  static String normalize(String value) {
    return value
        .replaceAll('-', '')
        .replaceAll(RegExp(r'\s'), '')
        .toUpperCase();
  }

  static bool isValid(String value) {
    return _validPattern.hasMatch(normalize(value));
  }
}
