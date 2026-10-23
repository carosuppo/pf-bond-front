import 'package:flutter/material.dart';

import '../widgets/create_expense_account_form.dart';

class CreateExpenseAccountScreen extends StatelessWidget {
  const CreateExpenseAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const CreateExpenseAccountForm());
  }
}
