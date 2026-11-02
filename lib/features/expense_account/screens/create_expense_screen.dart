import 'package:flutter/material.dart';

import '../models/expense_account_detail_model.response.dart';
import '../widgets/create_expense_form.dart';

class CreateExpenseScreen extends StatelessWidget {
  const CreateExpenseScreen({
    super.key,
    required this.accountId,
    this.expense,
    this.hasConfirmedPayments = false,
  });

  final int accountId;
  final AccountMovementModel? expense;
  final bool hasConfirmedPayments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CreateExpenseForm(
        accountId: accountId,
        expense: expense,
        hasConfirmedPayments: hasConfirmedPayments,
      ),
    );
  }
}
