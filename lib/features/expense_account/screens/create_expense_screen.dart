import 'package:flutter/material.dart';

import '../widgets/create_expense_form.dart';

class CreateExpenseScreen extends StatelessWidget {
  const CreateExpenseScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: CreateExpenseForm(accountId: accountId));
  }
}
