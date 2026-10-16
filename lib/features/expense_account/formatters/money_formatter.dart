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
}
