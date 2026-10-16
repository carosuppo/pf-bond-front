import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/user_avatar.dart';
import '../widgets/account_header_card.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';

class ExpenseAccountBalanceScreen extends StatelessWidget {
  const ExpenseAccountBalanceScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _BalanceContent(accountId: accountId)),
    );
  }
}

class _BalanceContent extends StatefulWidget {
  const _BalanceContent({required this.accountId});

  final int accountId;

  @override
  State<_BalanceContent> createState() => _BalanceContentState();
}

class _BalanceContentState extends State<_BalanceContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ExpenseAccountProvider>().loadAccountDetail(
        accountId: widget.accountId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final detail = provider.accountDetail;

    return Column(
      children: [
        AppScreenHeader(
          title: 'Mi balance',
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (provider.isDetailLoading || detail == null) {
                if (provider.detailErrorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        provider.detailErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return _BalanceBody(detail: detail);
            },
          ),
        ),
      ],
    );
  }
}

class _BalanceBody extends StatelessWidget {
  const _BalanceBody({required this.detail});

  final ExpenseAccountDetailResponseModel detail;

  @override
  Widget build(BuildContext context) {
    final isOwed = detail.myStatus == BalanceStatus.aFavor;
    final isDebtor = detail.myStatus == BalanceStatus.enContra;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BalanceHeaderCard(detail: detail),
          const SizedBox(height: 20),
          if (isOwed)
            _DebtList(
              title: '¿Quién te debe?',
              debts: detail.debtsToMe,
              groupId: detail.groupId,
            )
          else if (isDebtor)
            _DebtList(
              title: '¿A quién le debés?',
              debts: detail.myDebts,
              groupId: detail.groupId,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.fieldColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No tenés deudas pendientes en esta cuenta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceHeaderCard extends StatelessWidget {
  const _BalanceHeaderCard({required this.detail});

  final ExpenseAccountDetailResponseModel detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccountHeaderCard(
          name: detail.name,
          groupName: detail.groupName,
          eventName: detail.eventName,
        ),
        const SizedBox(height: 14),
        Text(
          MoneyFormatter.formatCentsShort(detail.myBalanceCents),
          style: TextStyle(
            color: detail.myStatus.color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (detail.myStatus != BalanceStatus.saldado) ...[
          const SizedBox(height: 8),
          StatusPill(
            text:
                '${detail.myStatus == BalanceStatus.aFavor ? 'Te deben' : 'Debés'} '
                '${MoneyFormatter.formatCentsShort(detail.myStatus == BalanceStatus.aFavor ? detail.debtsToMe.fold<int>(0, (sum, debt) => sum + debt.amountCents) : detail.myDebts.fold<int>(0, (sum, debt) => sum + debt.amountCents))}',
            color: detail.myStatus.color,
          ),
        ],
      ],
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({
    required this.title,
    required this.debts,
    required this.groupId,
  });

  final String title;
  final List<AccountDebtModel> debts;
  final int groupId;

  AvatarStackItem _item(BuildContext context, int memberId) {
    final details = context.read<GroupProvider>().groupDetails;

    if (details != null && details.id == groupId) {
      for (final member in details.members) {
        if (member.id == memberId) {
          return AvatarStackItem(
            name: member.name,
            photoUrl: member.profilePhoto,
          );
        }
      }
    }

    return const AvatarStackItem(name: 'Miembro');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(14),
          color: AppColors.fieldColor,
          child: Column(
            children: [
              for (final debt in debts)
                _DebtRow(
                  item: _item(context, debt.memberId),
                  amountCents: debt.amountCents,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.item, required this.amountCents});

  final AvatarStackItem item;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          UserAvatar(name: item.name, photoUrl: item.photoUrl, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
          ),
          Text(
            MoneyFormatter.formatCentsShort(amountCents),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
