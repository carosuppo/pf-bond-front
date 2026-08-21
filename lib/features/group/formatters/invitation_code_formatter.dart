import 'package:flutter/services.dart';

class InvitationCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll('-', '').toUpperCase();
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
