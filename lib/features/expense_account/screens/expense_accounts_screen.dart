import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/balance_status.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_balance_label.dart';

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

    await context.read<ExpenseAccountProvider>().loadAccounts();
  }

  Future<void> _goToDetail(BuildContext context, int accountId) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountDetail,
      arguments: {'accountId': accountId},
    );

    if (!context.mounted) {
      return;
    }

    await context.read<ExpenseAccountProvider>().loadAccounts();
  }

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
            Expanded(child: _AccountsContent(onTap: _goToDetail)),
          ],
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

class _AccountsContent extends StatefulWidget {
  const _AccountsContent({required this.onTap});

  final Future<void> Function(BuildContext context, int accountId) onTap;

  @override
  State<_AccountsContent> createState() => _AccountsContentState();
}

class _AccountsContentState extends State<_AccountsContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ExpenseAccountProvider>().loadAccounts();
    });
  }

  Future<void> _reload() async {
    await context.read<ExpenseAccountProvider>().loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();

    if (provider.isAccountsLoading && provider.accounts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.accountsErrorMessage != null && provider.accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.mutedText,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                provider.accountsErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: provider.isAccountsLoading ? null : _reload,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.accounts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 80), _EmptyAccounts()],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: provider.accounts.length,
        itemBuilder: (_, index) {
          final account = provider.accounts[index];
          final subtitle = account.eventName == null
              ? account.groupName
              : '${account.groupName} · ${account.eventName}';

          return _AccountCard(
            name: account.name,
            subtitle: subtitle,
            status: account.status,
            balanceCents: account.balanceCents,
            onTap: () => widget.onTap(context, account.id),
          );
        },
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
            'Sin cuentas',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No estás asociado a ninguna cuenta. Creá la primera con el botón +.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.balanceCents,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final BalanceStatus status;
  final int balanceCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AccountBalanceLabel(status: status, balanceCents: balanceCents),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
