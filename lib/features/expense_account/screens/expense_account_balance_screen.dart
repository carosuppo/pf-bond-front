import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../group/models/get_group_model.response.dart';
import '../balance/member_debt_trace.dart';
import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_header_card.dart';

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
        force: true,
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

              final d = detail;
              return _BalanceBody(detail: d);
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
    return AccountGroupDetailsLoader(
      groupId: detail.groupId,
      builder: (context, groupDetails, isLoading, error) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (groupDetails == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No se pudo cargar el grupo de esta cuenta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 14),
              ),
            ),
          );
        }
        return _BalanceBodyContent(detail: detail, groupDetails: groupDetails);
      },
    );
  }
}

class _BalanceBodyContent extends StatelessWidget {
  const _BalanceBodyContent({required this.detail, required this.groupDetails});

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel groupDetails;

  @override
  Widget build(BuildContext context) {
    final traces = calculateMemberDebtTraces(
      myMemberId: detail.myMemberId,
      movements: detail.movements,
    );
    final debtsToMe = traces
        .where((trace) => trace.netBalanceCents > 0)
        .toList(growable: false);
    final myDebts = traces
        .where((trace) => trace.netBalanceCents < 0)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BalanceHeaderCard(detail: detail),
          const SizedBox(height: 20),
          if (debtsToMe.isNotEmpty) ...[
            Text(
              '¿Quién te debe?',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            for (final debt in debtsToMe)
              _MemberDebtTile(
                trace: debt,
                myMemberId: detail.myMemberId,
                groupDetails: groupDetails,
              ),
          ],
          if (myDebts.isNotEmpty) ...[
            Text(
              '¿A quién le debés?',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            for (final debt in myDebts)
              _MemberDebtTile(
                trace: debt,
                myMemberId: detail.myMemberId,
                groupDetails: groupDetails,
              ),
          ],
          if (traces.isEmpty)
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
          'Saldo neto ${_saldoNetoLabel(detail.myStatus)}',
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MoneyFormatter.formatCentsShort(detail.myBalanceCents),
          style: TextStyle(
            color: detail.myStatus.color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _saldoNetoLabel(BalanceStatus status) {
    switch (status) {
      case BalanceStatus.aFavor:
        return 'a tu favor';
      case BalanceStatus.enContra:
        return 'en contra';
      case BalanceStatus.saldado:
        return 'saldado';
    }
  }
}

class _MemberDebtTile extends StatelessWidget {
  const _MemberDebtTile({
    required this.trace,
    required this.myMemberId,
    required this.groupDetails,
  });

  final MemberDebtTrace trace;
  final int myMemberId;
  final GetGroupResponseModel groupDetails;

  int get memberId => trace.memberId;
  bool get isOwed => trace.netBalanceCents > 0;

  String _nombreMiembro() {
    for (final member in groupDetails.members) {
      if (member.id == memberId) {
        return member.name;
      }
    }
    return 'Miembro';
  }

  String _etiquetaMovimiento(AccountMovementModel movement) {
    if (movement.kind == 'EXPENSE') {
      return movement.payerMemberId == myMemberId
          ? 'Adelantaste su parte'
          : 'Tu parte del gasto';
    }

    if (movement.fromMemberId == myMemberId) {
      return 'Pago realizado · reduce tu deuda';
    }
    return 'Pago recibido · reduce lo que te deben';
  }

  String _fecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _nombreMiembro();
    final amountCents = trace.netBalanceCents.abs();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: UserAvatar(name: nombre, radius: 20),
        title: Text(
          nombre,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${isOwed ? 'Te debe (neto)' : 'Le debés (neto)'} '
          '${MoneyFormatter.formatCentsShort(amountCents)}',
          style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final movement in trace.movements)
                  _MovementRow(
                    movement: movement.movement,
                    label: _etiquetaMovimiento(movement.movement),
                    date: _fecha(movement.movement.createdAt),
                    balanceChangeCents: movement.balanceChangeCents,
                    balanceAfterCents: movement.balanceAfterCents,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.movement,
    required this.label,
    required this.date,
    required this.balanceChangeCents,
    required this.balanceAfterCents,
  });

  final AccountMovementModel movement;
  final String label;
  final String date;
  final int balanceChangeCents;
  final int balanceAfterCents;

  String _movementTitle() {
    final title = movement.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return movement.kind == 'EXPENSE' ? 'Gasto sin título' : 'Pago';
  }

  String _balanceLabel() {
    if (balanceAfterCents > 0) {
      return 'Después: te debe ${MoneyFormatter.formatCentsShort(balanceAfterCents)}';
    }
    if (balanceAfterCents < 0) {
      return 'Después: le debés ${MoneyFormatter.formatCentsShort(balanceAfterCents.abs())}';
    }
    return 'Después: quedan saldados';
  }

  @override
  Widget build(BuildContext context) {
    final signedChange = balanceChangeCents > 0
        ? '+${MoneyFormatter.formatCentsShort(balanceChangeCents)}'
        : '−${MoneyFormatter.formatCentsShort(balanceChangeCents.abs())}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movementTitle(),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$label · $date',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _balanceLabel(),
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            signedChange,
            style: TextStyle(
              color: balanceChangeCents > 0
                  ? AppColors.success
                  : AppColors.error,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
