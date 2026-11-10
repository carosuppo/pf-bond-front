import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';
import '../models/my_expense_account_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_separated_list.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppScreenHeader(title: 'Cuentas'),
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
  int? _selectedGroupId;
  BalanceStatus? _selectedBalanceStatus;
  final Set<BalanceStatus> _expandedBalanceGroups = {};

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

    final groups = <int, String>{
      for (final account in provider.accounts)
        account.groupId: account.groupName,
    };
    final groupOptions = groups.entries.toList()
      ..sort((first, second) => first.value.compareTo(second.value));
    final selectedGroupId = groups.containsKey(_selectedGroupId)
        ? _selectedGroupId
        : null;
    final groupFilters = <_AccountFilterOption<_GroupFilterValue>>[
      const _AccountFilterOption(
        value: _GroupFilterValue(groupId: null),
        label: 'Todos los grupos',
      ),
      for (final group in groupOptions)
        _AccountFilterOption(
          value: _GroupFilterValue(groupId: group.key),
          label: group.value,
        ),
    ];
    final filteredAccounts = provider.accounts
        .where((account) {
          return (selectedGroupId == null ||
                  account.groupId == selectedGroupId) &&
              (_selectedBalanceStatus == null ||
                  account.status == _selectedBalanceStatus);
        })
        .toList(growable: false);
    const balanceStatusOrder = [
      BalanceStatus.enContra,
      BalanceStatus.aFavor,
      BalanceStatus.saldado,
    ];
    final accountsByBalanceStatus =
        <BalanceStatus, List<MyExpenseAccountResponseModel>>{};

    for (final status in balanceStatusOrder) {
      final accountsForStatus = filteredAccounts
          .where((account) => account.status == status)
          .toList();
      accountsForStatus.sort(_compareAccountsByLastMovement);
      if (accountsForStatus.isNotEmpty) {
        accountsByBalanceStatus[status] = accountsForStatus;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Filtrar por:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AccountFilterDropdown<_GroupFilterValue>(
                        label: 'Grupo',
                        selectedLabel: selectedGroupId == null
                            ? 'Todos los grupos'
                            : groups[selectedGroupId]!,
                        options: groupFilters,
                        onSelected: (value) =>
                            setState(() => _selectedGroupId = value.groupId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _reload,
            child: filteredAccounts.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _NoMatchingAccounts(
                        onClear: () => setState(() {
                          _selectedGroupId = null;
                          _selectedBalanceStatus = null;
                        }),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: [
                      for (final status in balanceStatusOrder)
                        if (accountsByBalanceStatus[status]
                            case final accounts?)
                          _AccountSection(
                            status: status,
                            accounts: accounts,
                            isExpanded: _expandedBalanceGroups.contains(status),
                            onToggle: () {
                              setState(() {
                                if (!_expandedBalanceGroups.add(status)) {
                                  _expandedBalanceGroups.remove(status);
                                }
                              });
                            },
                            onTap: (accountId) =>
                                widget.onTap(context, accountId),
                          ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _AccountFilterDropdown<T> extends StatelessWidget {
  const _AccountFilterDropdown({
    required this.label,
    required this.selectedLabel,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String selectedLabel;
  final List<_AccountFilterOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<T>(
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
          color: AppColors.cardColor,
          surfaceTintColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final option in options)
              PopupMenuItem<T>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),
          ],
          child: InputDecorator(
            decoration: _filterDecoration(label).copyWith(
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.mutedText,
              ),
            ),
            isEmpty: false,
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
            ),
          ),
        );
      },
    );
  }
}

class _AccountFilterOption<T> {
  const _AccountFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

int _compareAccountsByLastMovement(
  MyExpenseAccountResponseModel first,
  MyExpenseAccountResponseModel second,
) {
  final firstMovementAt = first.lastMovementAt;
  final secondMovementAt = second.lastMovementAt;

  if (firstMovementAt == null && secondMovementAt != null) return 1;
  if (firstMovementAt != null && secondMovementAt == null) return -1;
  if (firstMovementAt != null && secondMovementAt != null) {
    final movementDateComparison = secondMovementAt.compareTo(firstMovementAt);
    if (movementDateComparison != 0) return movementDateComparison;
  }

  return first.name.compareTo(second.name);
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.status,
    required this.accounts,
    required this.isExpanded,
    required this.onToggle,
    required this.onTap,
  });

  final BalanceStatus status;
  final List<MyExpenseAccountResponseModel> accounts;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(int accountId) onTap;

  @override
  Widget build(BuildContext context) {
    final visibleAccounts = isExpanded || accounts.length <= 3
        ? accounts
        : accounts.take(3).toList(growable: false);
    final totalBalanceCents = accounts.fold<int>(
      0,
      (total, account) => total + account.balanceCents,
    );
    final showTotalBalance = status != BalanceStatus.saldado;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _titleForStatus(status),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AccountSeparatedList(
            itemCount: visibleAccounts.length,
            itemBuilder: (context, index) {
              final account = visibleAccounts[index];
              return _AccountCard(
                name: account.name,
                subtitle: account.eventName == null
                    ? account.groupName
                    : '${account.groupName} · ${account.eventName}',
                status: account.status,
                balanceCents: account.balanceCents,
                onTap: () => onTap(account.id),
              );
            },
          ),
          if (showTotalBalance || accounts.length > 3)
            Row(
              children: [
                if (showTotalBalance)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      'Total: ${MoneyFormatter.formatCentsShort(totalBalanceCents)}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                if (accounts.length > 3) const Spacer(),
                if (accounts.length > 3)
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      isExpanded ? 'Ver menos cuentas' : 'Ver más cuentas',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _titleForStatus(BalanceStatus value) {
    switch (value) {
      case BalanceStatus.enContra:
        return 'Saldo en contra';
      case BalanceStatus.aFavor:
        return 'Saldo a favor';
      case BalanceStatus.saldado:
        return 'Cuentas saldadas';
    }
  }
}

class _GroupFilterValue {
  const _GroupFilterValue({required this.groupId});

  final int? groupId;
}

InputDecoration _filterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.hint, fontSize: 12),
    floatingLabelStyle: const TextStyle(color: AppColors.hint, fontSize: 12),
    filled: true,
    fillColor: AppColors.cardColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _NoMatchingAccounts extends StatelessWidget {
  const _NoMatchingAccounts({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_list_off_rounded,
            color: AppColors.mutedText,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay cuentas que coincidan con los filtros.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
          TextButton(onPressed: onClear, child: const Text('Limpiar filtros')),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: AccountBalanceLabel(
                      status: status,
                      balanceCents: balanceCents,
                      large: true,
                      showStatus: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
