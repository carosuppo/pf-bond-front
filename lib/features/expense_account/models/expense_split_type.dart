enum ExpenseSplitType { equal, custom }

extension ExpenseSplitTypeValue on ExpenseSplitType {
  String get value {
    switch (this) {
      case ExpenseSplitType.equal:
        return 'EQUAL';
      case ExpenseSplitType.custom:
        return 'CUSTOM';
    }
  }

  String get label {
    switch (this) {
      case ExpenseSplitType.equal:
        return 'Partes iguales';
      case ExpenseSplitType.custom:
        return 'Personalizado';
    }
  }
}

ExpenseSplitType expenseSplitTypeFromString(String value) {
  switch (value) {
    case 'EQUAL':
      return ExpenseSplitType.equal;
    case 'CUSTOM':
      return ExpenseSplitType.custom;
    default:
      throw FormatException('Tipo de reparto desconocido: $value');
  }
}
