import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../event/formatters/event_date_formatter.dart';
import '../balance/member_debt_trace.dart';
import '../formatters/account_movement_formatter.dart';
import '../formatters/money_formatter.dart';
import '../models/expense_account_detail_model.response.dart';

class AccountMemberDebtTile extends StatelessWidget {
  const AccountMemberDebtTile({
    super.key,
    required this.trace,
    required this.memberName,
    required this.myMemberId,
  });

  final MemberDebtTrace trace;
  final String memberName;
  final int myMemberId;

  bool get _isOwed => trace.netBalanceCents > 0;

  @override
  Widget build(BuildContext context) {
    final color = _isOwed ? AppColors.success : AppColors.error;
    final movements =
        trace.movements
            .where((movement) => movement.balanceChangeCents != 0)
            .toList()
          ..sort((first, second) {
            final firstDate =
                first.movement.settledAt ?? first.movement.createdAt;
            final secondDate =
                second.movement.settledAt ?? second.movement.createdAt;
            final dateOrder = secondDate.compareTo(firstDate);
            return dateOrder != 0
                ? dateOrder
                : second.movement.id.compareTo(first.movement.id);
          });

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide.none,
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide.none,
        ),
        leading: UserAvatar(name: memberName, radius: 19),
        title: Text(
          memberName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          MoneyFormatter.formatCentsShort(trace.netBalanceCents.abs()),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 260,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final traceMovement in movements)
                          _DebtTraceMovementRow(
                            traceMovement: traceMovement,
                            myMemberId: myMemberId,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtTraceMovementRow extends StatelessWidget {
  const _DebtTraceMovementRow({
    required this.traceMovement,
    required this.myMemberId,
  });

  final MemberDebtTraceMovement traceMovement;
  final int myMemberId;

  String _description(AccountMovementModel movement) {
    if (movement.kind == 'EXPENSE') {
      return movement.payerMemberId == myMemberId
          ? 'Pagaste un gasto'
          : 'Tu parte del gasto';
    }

    if (movement.kind == 'ADJUSTMENT') {
      return movement.debtorMemberId == myMemberId
          ? 'Ajuste pendiente · debés'
          : 'Ajuste pendiente · te deben';
    }

    if (movement.adjustmentId != null) {
      return 'Ajuste ya saldado';
    }

    if (movement.expenseShareId != null) {
      return 'Participación ya saldada';
    }

    return movement.fromMemberId == myMemberId
        ? 'Pago realizado'
        : 'Pago recibido';
  }

  @override
  Widget build(BuildContext context) {
    final movement = traceMovement.movement;
    final balanceChangeCents = traceMovement.balanceChangeCents;
    final changeLabel = balanceChangeCents > 0
        ? '+${MoneyFormatter.formatCentsShort(balanceChangeCents)}'
        : balanceChangeCents < 0
        ? '−${MoneyFormatter.formatCentsShort(balanceChangeCents.abs())}'
        : 'Sin cambio';
    final changeColor = balanceChangeCents > 0
        ? AppColors.success
        : balanceChangeCents < 0
        ? AppColors.error
        : AppColors.mutedText;
    final movementDate = movement.settledAt ?? movement.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  accountMovementTitle(movement),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                changeLabel,
                style: TextStyle(
                  color: changeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_description(movement)} · '
            '${EventDateFormatter.dayMonthYear(movementDate)}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
