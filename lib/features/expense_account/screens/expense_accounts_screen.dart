import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ExpenseAccountsScreen extends StatelessWidget {
  const ExpenseAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Cuentas',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Próximamente',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
