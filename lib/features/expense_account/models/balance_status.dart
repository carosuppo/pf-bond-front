import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum BalanceStatus { aFavor, enContra, saldado }

BalanceStatus balanceStatusFromString(String value) {
  switch (value) {
    case 'A_FAVOR':
      return BalanceStatus.aFavor;
    case 'EN_CONTRA':
      return BalanceStatus.enContra;
    case 'SALDADO':
      return BalanceStatus.saldado;
    default:
      throw FormatException('Estado de saldo desconocido: $value');
  }
}

extension BalanceStatusLabel on BalanceStatus {
  String get label {
    switch (this) {
      case BalanceStatus.aFavor:
        return 'A favor';
      case BalanceStatus.enContra:
        return 'En contra';
      case BalanceStatus.saldado:
        return 'Saldado';
    }
  }

  Color get color {
    switch (this) {
      case BalanceStatus.aFavor:
        return AppColors.success;
      case BalanceStatus.enContra:
        return AppColors.error;
      case BalanceStatus.saldado:
        return AppColors.mutedText;
    }
  }
}
