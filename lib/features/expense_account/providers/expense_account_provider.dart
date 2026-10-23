import 'package:flutter/material.dart';

import '../models/create_expense_account_model.request.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_account_model.response.dart';
import '../models/my_expense_account_model.response.dart';
import '../services/expense_account_service.dart';

class ExpenseAccountProvider extends ChangeNotifier {
  final ExpenseAccountService _expenseAccountService;

  ExpenseAccountProvider(this._expenseAccountService);

  bool isLoading = false;
  String? errorMessage;
  ExpenseAccountResponseModel? expenseAccount;
  List<MyExpenseAccountResponseModel> accounts = [];
  bool isAccountsLoading = false;
  String? accountsErrorMessage;
  ExpenseAccountDetailResponseModel? accountDetail;
  bool isDetailLoading = false;
  String? detailErrorMessage;
  int? _detailAccountId;
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
        groupId: groupId,
        memberIds: memberIds,
        eventId: eventId,
      );

      final createdAccount = await _expenseAccountService.createExpenseAccount(
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
    accounts = [];
    isAccountsLoading = false;
    accountsErrorMessage = null;
    accountDetail = null;
    isDetailLoading = false;
    detailErrorMessage = null;
    _detailAccountId = null;
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    final sessionVersion = _sessionVersion;
    isAccountsLoading = true;
    accountsErrorMessage = null;
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getMyAccounts();
      if (sessionVersion != _sessionVersion) return;
      accounts = loaded;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return;
      accountsErrorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (sessionVersion == _sessionVersion) {
        isAccountsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAccountDetail({required int accountId}) async {
    final sessionVersion = _sessionVersion;
    if (_detailAccountId == accountId && accountDetail != null) {
      return;
    }
    _detailAccountId = accountId;
    isDetailLoading = true;
    detailErrorMessage = null;
    accountDetail = null;
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getAccountDetail(
        accountId: accountId,
      );
      if (sessionVersion != _sessionVersion) return;
      if (_detailAccountId != accountId) return;
      accountDetail = loaded;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return;
      if (_detailAccountId != accountId) return;
      detailErrorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (sessionVersion == _sessionVersion && _detailAccountId == accountId) {
        isDetailLoading = false;
        notifyListeners();
      }
    }
  }

  void clearDetail() {
    _detailAccountId = null;
    accountDetail = null;
    isDetailLoading = false;
    detailErrorMessage = null;
    notifyListeners();
  }
}
