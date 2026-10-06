import 'package:flutter/material.dart';

import '../models/create_expense_account_model.request.dart';
import '../models/expense_account_model.response.dart';
import '../services/expense_account_service.dart';

class ExpenseAccountProvider extends ChangeNotifier {
  final ExpenseAccountService _expenseAccountService;

  ExpenseAccountProvider(this._expenseAccountService);

  bool isLoading = false;
  String? errorMessage;
  ExpenseAccountResponseModel? expenseAccount;
  int _sessionVersion = 0;

  Future<bool> createExpenseAccount({
    required int groupId,
    required String name,
    required List<int> memberIds,
    int? eventId,
  }) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    expenseAccount = null;

    notifyListeners();

    try {
      final request = CreateExpenseAccountRequestModel(
        name: name,
        memberIds: memberIds,
        eventId: eventId,
      );

      final createdAccount = await _expenseAccountService.createExpenseAccount(
        groupId: groupId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;
      expenseAccount = createdAccount;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void resetSessionState() {
    _sessionVersion++;
    isLoading = false;
    errorMessage = null;
    expenseAccount = null;
    notifyListeners();
  }
}
