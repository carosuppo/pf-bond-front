import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/user_avatar.dart';
import '../widgets/account_header_card.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';

class ExpenseAccountDetailScreen extends StatelessWidget {
  const ExpenseAccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _SummaryContent(accountId: accountId)),
    );
  }
}

class _SummaryContent extends StatefulWidget {
  const _SummaryContent({required this.accountId});

  final int accountId;

  @override
  State<_SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<_SummaryContent> {
  late final ExpenseAccountProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseAccountProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _provider.loadAccountDetail(accountId: widget.accountId);
    });
  }

  @override
  void dispose() {
    _provider.clearDetail();
    super.dispose();
  }

  Future<void> _goToBalance() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountBalance,
      arguments: {'accountId': widget.accountId},
    );
  }

  Future<void> _goToMovements() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountMovements,
      arguments: {'accountId': widget.accountId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final detail = provider.accountDetail;

    return Column(
      children: [
        AppScreenHeader(
          title: provider.accountDetail?.name ?? 'Cuenta',
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (provider.isDetailLoading || detail == null) {
                if (provider.detailErrorMessage != null) {
                  return _SummaryError(
                    message: provider.detailErrorMessage!,
                    onRetry: () =>
                        provider.loadAccountDetail(accountId: widget.accountId),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return _SummaryBody(
                detail: detail,
                onBalanceTap: _goToBalance,
                onMovementsTap: _goToMovements,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.detail,
    required this.onBalanceTap,
    required this.onMovementsTap,
  });

  final ExpenseAccountDetailResponseModel detail;
  final VoidCallback onBalanceTap;
  final VoidCallback onMovementsTap;

  @override
  Widget build(BuildContext context) {
    final expensesCount = detail.movements
        .where((movement) => movement.kind == 'EXPENSE')
        .length;
    final paymentsCount = detail.movements
        .where((movement) => movement.kind == 'PAYMENT')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountHeaderCard(
            name: detail.name,
            groupName: detail.groupName,
            eventName: detail.eventName,
          ),
          const SizedBox(height: 12),
          _BalanceCard(detail: detail, onBalanceTap: onBalanceTap),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_outlined,
                  count: expensesCount,
                  label: 'Gastos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.payments_outlined,
                  count: paymentsCount,
                  label: 'Pagos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(text: 'Ver movimientos', onPressed: onMovementsTap),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.detail, required this.onBalanceTap});

  final ExpenseAccountDetailResponseModel detail;
  final VoidCallback onBalanceTap;

  List<int> get _highlightedMemberIds {
    final debts = [
      ...detail.debtsToMe.map((debt) => debt.memberId),
      ...detail.myDebts.map((debt) => debt.memberId),
    ];

    if (debts.isNotEmpty) {
      return debts.toSet().toList(growable: false);
    }

    return detail.members.map((member) => member.memberId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saldo de la cuenta',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusPill(
                text: detail.myStatus.label,
                color: detail.myStatus.color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            MoneyFormatter.formatCentsShort(detail.myBalanceCents),
            style: TextStyle(
              color: detail.myStatus.color,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (detail.myStatus != BalanceStatus.saldado) ...[
            const SizedBox(height: 8),
            _DebtsPill(detail: detail),
          ],
          const SizedBox(height: 14),
          _MembersPreview(
            memberIds: detail.members
                .map((member) => member.memberId)
                .toList(growable: false),
            previewIds: _highlightedMemberIds,
            groupId: detail.groupId,
          ),
          const SizedBox(height: 12),
          _TextActionButton(text: 'Ver mi balance', onTap: onBalanceTap),
        ],
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtsPill extends StatelessWidget {
  const _DebtsPill({required this.detail});

  final ExpenseAccountDetailResponseModel detail;

  @override
  Widget build(BuildContext context) {
    final isOwed = detail.myStatus == BalanceStatus.aFavor;
    final total = isOwed
        ? detail.debtsToMe.fold<int>(0, (sum, debt) => sum + debt.amountCents)
        : detail.myDebts.fold<int>(0, (sum, debt) => sum + debt.amountCents);

    return StatusPill(
      text:
          '${isOwed ? 'Te deben' : 'Debés'} ${MoneyFormatter.formatCentsShort(total)}',
      color: detail.myStatus.color,
    );
  }
}

class _MembersPreview extends StatefulWidget {
  const _MembersPreview({
    required this.memberIds,
    required this.previewIds,
    required this.groupId,
  });

  final List<int> memberIds;
  final List<int> previewIds;
  final int groupId;

  @override
  State<_MembersPreview> createState() => _MembersPreviewState();
}

class _MembersPreviewState extends State<_MembersPreview> {
  bool _expanded = false;

  List<AvatarStackItem> _items(BuildContext context, {bool all = false}) {
    final details = context.watch<GroupProvider>().groupDetails;
    final byId = {
      if (details != null && details.id == widget.groupId)
        for (final member in details.members) member.id: member,
    };
    final ids = all ? widget.memberIds : widget.previewIds.take(5);

    return [
      for (final memberId in ids)
        AvatarStackItem(
          name: byId[memberId]?.name ?? 'Miembro',
          photoUrl: byId[memberId]?.profilePhoto,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AvatarStack(items: _items(context)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.mutedText,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          for (final item in _items(context, all: true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  UserAvatar(
                    name: item.name,
                    photoUrl: item.photoUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mutedText, size: 24),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
