import 'package:flutter/material.dart';

import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';

class AccountBalanceLabel extends StatelessWidget {
  const AccountBalanceLabel({
    super.key,
    required this.status,
    required this.balanceCents,
    this.large = false,
  });

  final BalanceStatus status;
  final int balanceCents;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          MoneyFormatter.formatCentsShort(balanceCents),
          style: TextStyle(
            color: status.color,
            fontSize: large ? 28 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status.label,
          style: TextStyle(color: status.color, fontSize: large ? 14 : 12),
        ),
      ],
    );
  }
}
