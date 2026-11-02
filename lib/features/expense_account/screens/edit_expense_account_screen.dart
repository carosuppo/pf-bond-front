import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/edit_expense_account_form.dart';

class EditExpenseAccountScreen extends StatelessWidget {
  const EditExpenseAccountScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: EditExpenseAccountForm(accountId: accountId),
    );
  }
}
