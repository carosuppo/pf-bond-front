import '../../group/models/get_member_model.response.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_model.response.dart';

String accountMovementTitle(AccountMovementModel movement) {
  final title = (movement.title ?? movement.expenseTitle)?.trim();

  if (movement.kind == 'ADJUSTMENT') {
    return title == null || title.isEmpty
        ? 'Ajuste económico'
        : 'Ajuste · $title';
  }

  if (movement.kind == 'PAYMENT') {
    final paymentLabel = movement.adjustmentId == null
        ? 'Pago'
        : 'Pago de ajuste';
    return title == null || title.isEmpty
        ? paymentLabel
        : '$paymentLabel · $title';
  }

  if (title != null && title.isNotEmpty) return title;
  return movement.kind == 'EXPENSE' ? 'Gasto' : 'Movimiento';
}

int? accountMovementCreatorUserId({
  required AccountMovementModel movement,
  required int accountId,
  ExpenseResponseModel? createdExpense,
  ExpenseResponseModel? updatedExpense,
}) {
  if (movement.createdByUserId != null) return movement.createdByUserId;

  final relatedExpenseId = switch (movement.kind) {
    'EXPENSE' => movement.id,
    'ADJUSTMENT' => movement.expenseId,
    _ => null,
  };
  if (relatedExpenseId == null) return null;

  for (final expense in [createdExpense, updatedExpense]) {
    if (expense?.id == relatedExpenseId &&
        expense?.expenseAccountId == accountId &&
        expense?.createdByUserId != null) {
      return expense!.createdByUserId;
    }
  }

  return null;
}

String accountMovementCreatorSubtitle({
  required AccountMovementModel movement,
  required int accountId,
  required List<AccountMovementModel> allMovements,
  required List<GetMemberResponseModel> groupMembers,
  required int? currentUserId,
  ExpenseResponseModel? createdExpense,
  ExpenseResponseModel? updatedExpense,
}) {
  var creatorUserId = accountMovementCreatorUserId(
    movement: movement,
    accountId: accountId,
    createdExpense: createdExpense,
    updatedExpense: updatedExpense,
  );

  if (creatorUserId == null &&
      movement.kind == 'PAYMENT' &&
      movement.fromMemberId != null) {
    for (final member in groupMembers) {
      if (member.id == movement.fromMemberId) {
        creatorUserId = member.idUser;
        break;
      }
    }
  }

  if (creatorUserId == null &&
      movement.kind == 'ADJUSTMENT' &&
      movement.expenseId != null) {
    for (final expenseMovement in allMovements) {
      if (expenseMovement.kind == 'EXPENSE' &&
          expenseMovement.id == movement.expenseId) {
        creatorUserId = accountMovementCreatorUserId(
          movement: expenseMovement,
          accountId: accountId,
          createdExpense: createdExpense,
          updatedExpense: updatedExpense,
        );
        break;
      }
    }
  }

  if (creatorUserId == null) return 'Autor no disponible';
  if (creatorUserId == currentUserId) return 'Lo registraste vos';

  for (final member in groupMembers) {
    if (member.idUser == creatorUserId) return 'Registró ${member.name}';
  }

  return 'Registró un integrante';
}
