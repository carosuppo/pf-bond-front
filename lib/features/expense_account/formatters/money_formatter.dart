class MoneyFormatter {
  MoneyFormatter._();

  /// Formatea centavos al estilo argentino: 123450 -> '$ 1.234,50'.
  static String formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final absolute = cents.abs();
    final pesos = absolute ~/ 100;
    final rest = (absolute % 100).toString().padLeft(2, '0');

    return '$sign\$ ${_thousands(pesos)},$rest';
  }

  /// Como [formatCents] pero omite los decimales cuando son exactos:
  /// 245000 -> '$ 2.450'.
  static String formatCentsShort(int cents) {
    if (cents % 100 != 0) {
      return formatCents(cents);
    }

    final sign = cents < 0 ? '-' : '';
    final pesos = cents.abs() ~/ 100;

    return '$sign\$ ${_thousands(pesos)}';
  }

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  /// Convierte un importe escrito al estilo argentino a centavos:
  /// '1.234,50' -> 123450. Acepta coma o punto como separador decimal.
  /// Devuelve null si el texto no representa un importe válido.
  static int? parseCents(String value) {
    var normalized = value.trim().replaceAll(' ', '').replaceAll('\$', '');

    if (normalized.isEmpty) {
      return null;
    }

    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');

    if (hasComma && hasDot) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      normalized = normalized.replaceAll(',', '.');
    }

    final amount = double.tryParse(normalized);

    if (amount == null || amount.isNaN || amount.isInfinite || amount <= 0) {
      return null;
    }

    return (amount * 100).round();
  }
}
