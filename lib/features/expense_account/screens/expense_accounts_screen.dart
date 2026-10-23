import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';

class ExpenseAccountsScreen extends StatelessWidget {
  const ExpenseAccountsScreen({super.key});

  Future<void> _goToCreateExpenseAccount(BuildContext context) async {
    final created = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.createExpenseAccount);

    if (!context.mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta creada correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.fieldColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cuentas',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todavía no hay cuentas. Creá la primera con el botón +.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        highlightElevation: 12,
        onPressed: () => _goToCreateExpenseAccount(context),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}
