import 'package:flutter/material.dart';

import '../models/create_expense_account_model.request.dart';
import '../models/create_expense_model.request.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_account_model.response.dart';
import '../models/expense_payment_model.response.dart';
import '../models/expense_model.response.dart';
import '../models/expense_split_type.dart';
import '../models/my_expense_account_model.response.dart';
import '../models/pending_expense_adjustment_model.response.dart';
import '../models/pending_expense_share_model.response.dart';
import '../models/update_expense_account_model.request.dart';
import '../services/expense_account_service.dart';

class ExpenseAccountProvider extends ChangeNotifier {
  final ExpenseAccountService _expenseAccountService;

  ExpenseAccountProvider(this._expenseAccountService);

  bool isLoading = false;
  String? errorMessage;
  ExpenseAccountResponseModel? expenseAccount;
  ExpenseAccountResponseModel? updatedExpenseAccount;
  bool isUpdatingExpenseAccount = false;
  String? updateExpenseAccountErrorMessage;
  List<MyExpenseAccountResponseModel> accounts = [];
  bool isAccountsLoading = false;
  String? accountsErrorMessage;
  ExpenseAccountDetailResponseModel? accountDetail;
  bool isDetailLoading = false;
  String? detailErrorMessage;
  int? _detailAccountId;
  ExpenseResponseModel? createdExpense;
  List<PendingExpenseShareResponseModel> pendingExpenseShares = [];
  bool isPendingExpenseSharesLoading = false;
  String? pendingExpenseSharesErrorMessage;
  List<PendingExpenseAdjustmentResponseModel> pendingExpenseAdjustments = [];
  bool isPendingExpenseAdjustmentsLoading = false;
  String? pendingExpenseAdjustmentsErrorMessage;
  List<ExpensePaymentResponseModel> registeredExpensePayments = [];
  bool isRegisteringExpensePayments = false;
  String? paymentRegistrationErrorMessage;
  bool isAnnullingExpensePayment = false;
  int? annullingExpensePaymentId;
  String? annulExpensePaymentErrorMessage;
  ExpensePaymentResponseModel? annulledExpensePayment;
  bool isDeletingExpenseAccount = false;
  String? _deleteExpenseAccountErrorMessage;
  int? _deleteExpenseAccountErrorAccountId;
  int? _pendingSharesAccountId;
  bool _hasLoadedPendingShares = false;
  int? _pendingAdjustmentsAccountId;
  bool _hasLoadedPendingAdjustments = false;
  bool isUpdatingExpense = false;
  String? updateExpenseErrorMessage;
  ExpenseResponseModel? updatedExpense;
  bool isDeletingExpense = false;
  int? deletingExpenseId;
  String? deleteExpenseErrorMessage;
  int _sessionVersion = 0;
  final Set<int> _deletedAccountIds = {};

  String? get deleteExpenseAccountErrorMessage =>
      _deleteExpenseAccountErrorAccountId == _detailAccountId
      ? _deleteExpenseAccountErrorMessage
      : null;

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

  Future<bool> updateExpenseAccount({
    required int accountId,
    required UpdateExpenseAccountRequestModel request,
  }) async {
    if (isUpdatingExpenseAccount) return false;

    final sessionVersion = _sessionVersion;
    isUpdatingExpenseAccount = true;
    updateExpenseAccountErrorMessage = null;
    updatedExpenseAccount = null;
    notifyListeners();

    try {
      final updated = await _expenseAccountService.updateExpenseAccount(
        accountId: accountId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;
      updatedExpenseAccount = updated;

      await loadAccounts();
      if (sessionVersion != _sessionVersion) return false;

      final currentDetail = accountDetail;
      if (currentDetail?.id == accountId &&
          !updated.memberIds.contains(currentDetail!.myMemberId)) {
        clearDetail();
      } else {
        await loadAccountDetail(accountId: accountId, force: true);
        if (sessionVersion != _sessionVersion) return false;
      }

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      updateExpenseAccountErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isUpdatingExpenseAccount = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteExpenseAccount({required int accountId}) async {
    if (isDeletingExpenseAccount || _deletedAccountIds.contains(accountId)) {
      return false;
    }

    final sessionVersion = _sessionVersion;
    isDeletingExpenseAccount = true;
    _deleteExpenseAccountErrorMessage = null;
    _deleteExpenseAccountErrorAccountId = accountId;
    notifyListeners();

    try {
      await _expenseAccountService.deleteExpenseAccount(accountId: accountId);
      if (sessionVersion != _sessionVersion) return false;

      _deletedAccountIds.add(accountId);
      accounts = accounts
          .where((account) => account.id != accountId)
          .toList(growable: false);

      if (_detailAccountId == accountId) {
        _detailAccountId = null;
        accountDetail = null;
        isDetailLoading = false;
        detailErrorMessage = null;
      }
      if (_pendingSharesAccountId == accountId) {
        _pendingSharesAccountId = null;
        _hasLoadedPendingShares = false;
        pendingExpenseShares = [];
        isPendingExpenseSharesLoading = false;
        pendingExpenseSharesErrorMessage = null;
      }
      if (_pendingAdjustmentsAccountId == accountId) {
        _pendingAdjustmentsAccountId = null;
        _hasLoadedPendingAdjustments = false;
        pendingExpenseAdjustments = [];
        isPendingExpenseAdjustmentsLoading = false;
        pendingExpenseAdjustmentsErrorMessage = null;
      }
      if (expenseAccount?.id == accountId) expenseAccount = null;
      if (updatedExpenseAccount?.id == accountId) updatedExpenseAccount = null;
      registeredExpensePayments = [];
      annulledExpensePayment = null;
      notifyListeners();

      await loadAccounts();
      if (sessionVersion != _sessionVersion) return false;
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      _deleteExpenseAccountErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      _deleteExpenseAccountErrorAccountId = accountId;
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isDeletingExpenseAccount = false;
        notifyListeners();
      }
    }
  }

  void resetSessionState() {
    _sessionVersion++;
    isLoading = false;
    errorMessage = null;
    expenseAccount = null;
    updatedExpenseAccount = null;
    isUpdatingExpenseAccount = false;
    updateExpenseAccountErrorMessage = null;
    accounts = [];
    isAccountsLoading = false;
    accountsErrorMessage = null;
    accountDetail = null;
    isDetailLoading = false;
    detailErrorMessage = null;
    _detailAccountId = null;
    createdExpense = null;
    pendingExpenseShares = [];
    isPendingExpenseSharesLoading = false;
    pendingExpenseSharesErrorMessage = null;
    pendingExpenseAdjustments = [];
    isPendingExpenseAdjustmentsLoading = false;
    pendingExpenseAdjustmentsErrorMessage = null;
    registeredExpensePayments = [];
    isRegisteringExpensePayments = false;
    paymentRegistrationErrorMessage = null;
    isAnnullingExpensePayment = false;
    annullingExpensePaymentId = null;
    annulExpensePaymentErrorMessage = null;
    annulledExpensePayment = null;
    isDeletingExpenseAccount = false;
    _deleteExpenseAccountErrorMessage = null;
    _deleteExpenseAccountErrorAccountId = null;
    _pendingSharesAccountId = null;
    _hasLoadedPendingShares = false;
    _pendingAdjustmentsAccountId = null;
    _hasLoadedPendingAdjustments = false;
    isUpdatingExpense = false;
    updateExpenseErrorMessage = null;
    updatedExpense = null;
    isDeletingExpense = false;
    deletingExpenseId = null;
    deleteExpenseErrorMessage = null;
    _deletedAccountIds.clear();
    notifyListeners();
  }

  Future<void> loadAccounts({bool clearOnError = false}) async {
    final sessionVersion = _sessionVersion;
    isAccountsLoading = true;
    accountsErrorMessage = null;
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getMyAccounts();
      if (sessionVersion != _sessionVersion) return;
      accounts = loaded
          .where((account) => !_deletedAccountIds.contains(account.id))
          .toList(growable: false);
    } catch (error) {
      if (sessionVersion != _sessionVersion) return;
      if (clearOnError) accounts = [];
      accountsErrorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (sessionVersion == _sessionVersion) {
        isAccountsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAccountDetail({
    required int accountId,
    bool force = false,
  }) async {
    final sessionVersion = _sessionVersion;
    if (_detailAccountId != accountId) {
      _deleteExpenseAccountErrorMessage = null;
      _deleteExpenseAccountErrorAccountId = null;
    }
    if (_deletedAccountIds.contains(accountId)) {
      _detailAccountId = null;
      accountDetail = null;
      isDetailLoading = false;
      detailErrorMessage = 'La cuenta ya no está disponible.';
      notifyListeners();
      return;
    }
    final hasLoadedDetail =
        _detailAccountId == accountId && accountDetail != null;
    if (hasLoadedDetail && !force) {
      return;
    }
    _detailAccountId = accountId;
    detailErrorMessage = null;
    if (!hasLoadedDetail) {
      isDetailLoading = true;
      accountDetail = null;
    }
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getAccountDetail(
        accountId: accountId,
      );
      if (sessionVersion != _sessionVersion) return;
      if (_detailAccountId != accountId) return;
      if (_deletedAccountIds.contains(accountId)) return;
      accountDetail = loaded;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return;
      if (_detailAccountId != accountId) return;
      if (!hasLoadedDetail || force) {
        detailErrorMessage = error.toString().replaceFirst('Exception: ', '');
        if (force) accountDetail = null;
      }
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
    _deleteExpenseAccountErrorMessage = null;
    _deleteExpenseAccountErrorAccountId = null;
    notifyListeners();
  }

  Future<void> loadPendingExpenseShares({
    required int accountId,
    bool force = false,
  }) async {
    final sessionVersion = _sessionVersion;
    if (_deletedAccountIds.contains(accountId)) {
      pendingExpenseShares = [];
      pendingExpenseSharesErrorMessage = 'La cuenta ya no está disponible.';
      notifyListeners();
      return;
    }
    if (_pendingSharesAccountId != accountId) {
      pendingExpenseShares = [];
      _hasLoadedPendingShares = false;
    }
    if (_pendingSharesAccountId == accountId &&
        _hasLoadedPendingShares &&
        !force) {
      return;
    }

    _pendingSharesAccountId = accountId;
    pendingExpenseSharesErrorMessage = null;
    paymentRegistrationErrorMessage = null;
    isPendingExpenseSharesLoading = true;
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getPendingExpenseShares(
        accountId: accountId,
      );
      if (sessionVersion != _sessionVersion ||
          _pendingSharesAccountId != accountId) {
        return;
      }
      if (_deletedAccountIds.contains(accountId)) return;
      pendingExpenseShares = loaded;
      _hasLoadedPendingShares = true;
    } catch (error) {
      if (sessionVersion != _sessionVersion ||
          _pendingSharesAccountId != accountId) {
        return;
      }
      pendingExpenseSharesErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      if (force) {
        pendingExpenseShares = [];
        _hasLoadedPendingShares = false;
      }
    } finally {
      if (sessionVersion == _sessionVersion &&
          _pendingSharesAccountId == accountId) {
        isPendingExpenseSharesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPendingExpenseAdjustments({
    required int accountId,
    bool force = false,
  }) async {
    final sessionVersion = _sessionVersion;
    if (_deletedAccountIds.contains(accountId)) {
      pendingExpenseAdjustments = [];
      pendingExpenseAdjustmentsErrorMessage =
          'La cuenta ya no está disponible.';
      notifyListeners();
      return;
    }
    if (_pendingAdjustmentsAccountId != accountId) {
      pendingExpenseAdjustments = [];
      _hasLoadedPendingAdjustments = false;
    }
    if (_pendingAdjustmentsAccountId == accountId &&
        _hasLoadedPendingAdjustments &&
        !force) {
      return;
    }

    _pendingAdjustmentsAccountId = accountId;
    pendingExpenseAdjustmentsErrorMessage = null;
    isPendingExpenseAdjustmentsLoading = true;
    notifyListeners();

    try {
      final loaded = await _expenseAccountService.getPendingExpenseAdjustments(
        accountId: accountId,
      );
      if (sessionVersion != _sessionVersion ||
          _pendingAdjustmentsAccountId != accountId) {
        return;
      }
      if (_deletedAccountIds.contains(accountId)) return;
      pendingExpenseAdjustments = loaded;
      _hasLoadedPendingAdjustments = true;
    } catch (error) {
      if (sessionVersion != _sessionVersion ||
          _pendingAdjustmentsAccountId != accountId) {
        return;
      }
      pendingExpenseAdjustmentsErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      if (force) {
        pendingExpenseAdjustments = [];
        _hasLoadedPendingAdjustments = false;
      }
    } finally {
      if (sessionVersion == _sessionVersion &&
          _pendingAdjustmentsAccountId == accountId) {
        isPendingExpenseAdjustmentsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> registerExpensePayments({
    required int accountId,
    required List<int> expenseShareIds,
    required List<int> adjustmentIds,
    bool registerAll = false,
  }) async {
    if (isRegisteringExpensePayments) {
      return false;
    }
    if (!registerAll && expenseShareIds.isEmpty && adjustmentIds.isEmpty) {
      paymentRegistrationErrorMessage =
          'Seleccioná al menos una participación o ajuste para registrar.';
      notifyListeners();
      return false;
    }

    final sessionVersion = _sessionVersion;
    isRegisteringExpensePayments = true;
    paymentRegistrationErrorMessage = null;
    registeredExpensePayments = [];
    notifyListeners();

    try {
      final registered = registerAll
          ? await _expenseAccountService.registerAllExpensePayments(
              accountId: accountId,
            )
          : await _expenseAccountService.registerExpensePayments(
              accountId: accountId,
              expenseShareIds: expenseShareIds,
              adjustmentIds: adjustmentIds,
            );
      if (sessionVersion != _sessionVersion) return false;
      registeredExpensePayments = registered;

      await Future.wait([
        loadPendingExpenseShares(accountId: accountId, force: true),
        loadPendingExpenseAdjustments(accountId: accountId, force: true),
        loadAccountDetail(accountId: accountId, force: true),
        loadAccounts(),
      ]);
      if (sessionVersion != _sessionVersion) return false;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      paymentRegistrationErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isRegisteringExpensePayments = false;
        notifyListeners();
      }
    }
  }

  Future<bool> annulExpensePayment({
    required int accountId,
    required int paymentId,
  }) async {
    if (isAnnullingExpensePayment) return false;

    final sessionVersion = _sessionVersion;
    isAnnullingExpensePayment = true;
    annullingExpensePaymentId = paymentId;
    annulExpensePaymentErrorMessage = null;
    annulledExpensePayment = null;
    notifyListeners();

    try {
      final annulled = await _expenseAccountService.annulExpensePayment(
        accountId: accountId,
        paymentId: paymentId,
      );
      if (sessionVersion != _sessionVersion) return false;
      annulledExpensePayment = annulled;

      await Future.wait([
        loadAccountDetail(accountId: accountId, force: true),
        loadAccounts(clearOnError: true),
        loadPendingExpenseShares(accountId: accountId, force: true),
        loadPendingExpenseAdjustments(accountId: accountId, force: true),
      ]);
      if (sessionVersion != _sessionVersion) return false;
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      annulExpensePaymentErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isAnnullingExpensePayment = false;
        annullingExpensePaymentId = null;
        notifyListeners();
      }
    }
  }

  Future<bool> createExpense({
    required int accountId,
    String? title,
    required int amountCents,
    required int payerMemberId,
    required ExpenseSplitType splitType,
    List<int>? participantIds,
    List<ExpenseShareRequestModel>? shares,
  }) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    createdExpense = null;

    notifyListeners();

    try {
      final request = CreateExpenseRequestModel(
        title: title,
        amountCents: amountCents,
        payerMemberId: payerMemberId,
        splitType: splitType,
        participantIds: participantIds,
        shares: shares,
      );

      final created = await _expenseAccountService.createExpense(
        accountId: accountId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;
      createdExpense = created;

      if (_detailAccountId == accountId) {
        await loadAccountDetail(accountId: accountId, force: true);
        if (sessionVersion != _sessionVersion) return false;
      }

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

  Future<bool> updateExpense({
    required int accountId,
    required int expenseId,
    String? title,
    required int amountCents,
    required int payerMemberId,
    required ExpenseSplitType splitType,
    List<int>? participantIds,
    List<ExpenseShareRequestModel>? shares,
  }) async {
    if (isUpdatingExpense) return false;

    final sessionVersion = _sessionVersion;
    isUpdatingExpense = true;
    updateExpenseErrorMessage = null;
    updatedExpense = null;
    notifyListeners();

    try {
      final request = CreateExpenseRequestModel(
        title: title,
        amountCents: amountCents,
        payerMemberId: payerMemberId,
        splitType: splitType,
        participantIds: participantIds,
        shares: shares,
      );
      final updated = await _expenseAccountService.updateExpense(
        accountId: accountId,
        expenseId: expenseId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;
      updatedExpense = updated;

      await Future.wait([
        loadAccountDetail(accountId: accountId, force: true),
        loadAccounts(),
        loadPendingExpenseShares(accountId: accountId, force: true),
        loadPendingExpenseAdjustments(accountId: accountId, force: true),
      ]);
      if (sessionVersion != _sessionVersion) return false;
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      updateExpenseErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isUpdatingExpense = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteExpense({
    required int accountId,
    required int expenseId,
  }) async {
    if (isDeletingExpense) return false;

    final sessionVersion = _sessionVersion;
    isDeletingExpense = true;
    deletingExpenseId = expenseId;
    deleteExpenseErrorMessage = null;
    notifyListeners();

    try {
      await _expenseAccountService.deleteExpense(
        accountId: accountId,
        expenseId: expenseId,
      );
      if (sessionVersion != _sessionVersion) return false;

      await Future.wait([
        loadAccountDetail(accountId: accountId, force: true),
        loadAccounts(clearOnError: true),
        loadPendingExpenseShares(accountId: accountId, force: true),
        loadPendingExpenseAdjustments(accountId: accountId, force: true),
      ]);
      if (sessionVersion != _sessionVersion) return false;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      deleteExpenseErrorMessage = error.toString().replaceFirst(
        'Exception: ',
        '',
      );
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isDeletingExpense = false;
        deletingExpenseId = null;
        notifyListeners();
      }
    }
  }
}
