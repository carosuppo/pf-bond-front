import 'package:flutter/services.dart';

class InvitationCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .replaceAll('-', '')
        .replaceAll(RegExp(r'\s'), '')
        .toUpperCase();
    final limited = raw.length > 6 ? raw.substring(0, 6) : raw;
    final formatted = limited.length > 3
        ? '${limited.substring(0, 3)}-${limited.substring(3)}'
        : limited;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatInvitationCode(String code) {
  final raw = code
      .replaceAll('-', '')
      .replaceAll(RegExp(r'\s'), '')
      .toUpperCase();

  if (raw.length <= 3) {
    return raw;
  }

  return '${raw.substring(0, 3)}-${raw.substring(3)}';
}
