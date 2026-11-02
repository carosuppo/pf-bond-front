import '../models/expense_account_detail_model.response.dart';

class MemberDebtTraceMovement {
  const MemberDebtTraceMovement({
    required this.movement,
    required this.balanceChangeCents,
    required this.balanceAfterCents,
  });

  final AccountMovementModel movement;

  /// Positive values increase the amount owed to the current member.
  final int balanceChangeCents;

  /// Positive means the other member owes the current member.
  final int balanceAfterCents;
}

class MemberDebtTrace {
  const MemberDebtTrace({
    required this.memberId,
    required this.netBalanceCents,
    required this.movements,
  });

  final int memberId;

  /// Positive means this member owes the current member; negative means the
  /// current member owes this member.
  final int netBalanceCents;
  final List<MemberDebtTraceMovement> movements;
}

class _MovementImpact {
  const _MovementImpact({
    required this.movement,
    required this.balanceChangeCents,
  });

  final AccountMovementModel movement;
  final int balanceChangeCents;
}

List<MemberDebtTrace> calculateMemberDebtTraces({
  required int myMemberId,
  required List<AccountMovementModel> movements,
}) {
  final impactsByMember = <int, List<_MovementImpact>>{};

  void addImpact(
    int memberId,
    AccountMovementModel movement,
    int amountCents, {
    bool includeZero = false,
  }) {
    if (memberId == myMemberId || (amountCents == 0 && !includeZero)) {
      return;
    }

    impactsByMember
        .putIfAbsent(memberId, () => [])
        .add(
          _MovementImpact(movement: movement, balanceChangeCents: amountCents),
        );
  }

  bool isPaymentForPaidShare(AccountMovementModel payment) {
    final expenseId = payment.expenseId;
    final memberId = payment.fromMemberId;
    final payerMemberId = payment.toMemberId;
    if (expenseId == null || memberId == null || payerMemberId == null) {
      return false;
    }

    return movements.any(
      (movement) =>
          movement.kind == 'EXPENSE' &&
          movement.id == expenseId &&
          movement.payerMemberId == payerMemberId &&
          movement.shares.any(
            (share) => share.memberId == memberId && share.isPaid,
          ),
    );
  }

  for (final movement in movements) {
    if (movement.kind == 'EXPENSE') {
      final payerMemberId = movement.payerMemberId;
      if (payerMemberId == null) {
        continue;
      }

      if (payerMemberId == myMemberId) {
        for (final share in movement.shares) {
          if (share.isCurrent &&
              share.memberId != myMemberId &&
              !share.isPaid) {
            addImpact(share.memberId, movement, share.amountCents);
          }
        }
        continue;
      }

      for (final share in movement.shares) {
        if (share.isCurrent && share.memberId == myMemberId && !share.isPaid) {
          addImpact(payerMemberId, movement, -share.amountCents);
          break;
        }
      }
      continue;
    }

    if (movement.kind == 'ADJUSTMENT') {
      final debtorMemberId = movement.debtorMemberId;
      final creditorMemberId = movement.creditorMemberId;
      if (debtorMemberId == null || creditorMemberId == null) {
        continue;
      }

      if (movement.status == 'PENDING') {
        if (debtorMemberId == myMemberId) {
          addImpact(creditorMemberId, movement, -movement.amountCents);
        } else if (creditorMemberId == myMemberId) {
          addImpact(debtorMemberId, movement, movement.amountCents);
        }
      }
      continue;
    }

    if (movement.expenseShareId != null) {
      if (!isPaymentForPaidShare(movement)) {
        continue;
      }

      if (movement.fromMemberId == myMemberId && movement.toMemberId != null) {
        addImpact(movement.toMemberId!, movement, 0, includeZero: true);
      } else if (movement.toMemberId == myMemberId &&
          movement.fromMemberId != null) {
        addImpact(movement.fromMemberId!, movement, 0, includeZero: true);
      }
      continue;
    }

    if (movement.fromMemberId == myMemberId) {
      final toMemberId = movement.toMemberId;
      if (toMemberId != null) {
        addImpact(toMemberId, movement, movement.amountCents);
      }
    } else if (movement.toMemberId == myMemberId) {
      final fromMemberId = movement.fromMemberId;
      if (fromMemberId != null) {
        addImpact(fromMemberId, movement, -movement.amountCents);
      }
    }
  }

  final traces = <MemberDebtTrace>[];

  for (final entry in impactsByMember.entries) {
    final orderedImpacts = entry.value.toList()
      ..sort((a, b) {
        final dateComparison = a.movement.createdAt.compareTo(
          b.movement.createdAt,
        );
        if (dateComparison != 0) {
          return dateComparison;
        }

        final idComparison = a.movement.id.compareTo(b.movement.id);
        if (idComparison != 0) {
          return idComparison;
        }

        return a.movement.kind.compareTo(b.movement.kind);
      });

    var balanceCents = 0;
    final traceMovements = orderedImpacts
        .map((impact) {
          balanceCents += impact.balanceChangeCents;
          return MemberDebtTraceMovement(
            movement: impact.movement,
            balanceChangeCents: impact.balanceChangeCents,
            balanceAfterCents: balanceCents,
          );
        })
        .toList(growable: false);

    if (balanceCents != 0) {
      traces.add(
        MemberDebtTrace(
          memberId: entry.key,
          netBalanceCents: balanceCents,
          movements: traceMovements,
        ),
      );
    }
  }

  traces.sort((a, b) {
    final amountComparison = b.netBalanceCents.abs().compareTo(
      a.netBalanceCents.abs(),
    );
    if (amountComparison != 0) {
      return amountComparison;
    }
    return a.memberId.compareTo(b.memberId);
  });

  return traces;
}

/// Returns the amount of an account movement attributable to a member.
/// Unrelated expenses and payments are omitted from that member's list.
int? memberMovementAmountCents(AccountMovementModel movement, int memberId) {
  if (movement.kind == 'EXPENSE') {
    int? memberShareAmountCents;
    for (final share in movement.shares) {
      if (share.memberId == memberId) {
        memberShareAmountCents = share.amountCents;
        break;
      }
    }

    if (memberShareAmountCents != null && memberShareAmountCents > 0) {
      return memberShareAmountCents;
    }

    if (movement.payerMemberId == memberId) {
      return movement.amountCents;
    }

    return null;
  }

  if (movement.kind == 'ADJUSTMENT') {
    if (movement.debtorMemberId == memberId ||
        movement.creditorMemberId == memberId) {
      return movement.amountCents;
    }
    return null;
  }

  if (movement.fromMemberId == memberId || movement.toMemberId == memberId) {
    return movement.amountCents;
  }

  return null;
}
