import '../../../core/network/api_client.dart';
import '../models/create_expense_account_model.request.dart';
import '../models/create_expense_model.request.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_account_model.response.dart';
import '../models/expense_payment_model.response.dart';
import '../models/expense_model.response.dart';
import '../models/my_expense_account_model.response.dart';
import '../models/pending_expense_share_model.response.dart';

class ExpenseAccountService {
  final ApiClient _apiClient;

  ExpenseAccountService(this._apiClient);

  Future<ExpenseAccountResponseModel> createExpenseAccount({
    required CreateExpenseAccountRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/expense-account',
      request.toJson(),
    );
    return ExpenseAccountResponseModel.fromJson(response);
  }

  Future<List<MyExpenseAccountResponseModel>> getMyAccounts() async {
    final response = await _apiClient.authenticatedGetList('/expense-account');
    return response
        .map(MyExpenseAccountResponseModel.fromJson)
        .toList(growable: false);
  }

  Future<ExpenseAccountDetailResponseModel> getAccountDetail({
    required int accountId,
  }) async {
    final response = await _apiClient.authenticatedGet(
      '/expense-account/$accountId',
    );
    return ExpenseAccountDetailResponseModel.fromJson(response);
  }

  Future<ExpenseResponseModel> createExpense({
    required int accountId,
    required CreateExpenseRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/expense-account/$accountId/expense',
      request.toJson(),
    );
    return ExpenseResponseModel.fromJson(response);
  }

  Future<List<PendingExpenseShareResponseModel>> getPendingExpenseShares({
    required int accountId,
  }) async {
    final response = await _apiClient.authenticatedGetList(
      '/expense-account/$accountId/pending-shares',
    );
    return response
        .map(PendingExpenseShareResponseModel.fromJson)
        .toList(growable: false);
  }

  Future<List<ExpensePaymentResponseModel>> registerExpensePayments({
    required int accountId,
    required List<int> expenseShareIds,
  }) async {
    final response = await _apiClient.authenticatedPostList(
      '/expense-account/$accountId/payments',
      body: {'expenseShareIds': expenseShareIds},
    );
    return response
        .map(ExpensePaymentResponseModel.fromJson)
        .toList(growable: false);
  }

  Future<List<ExpensePaymentResponseModel>> registerAllExpensePayments({
    required int accountId,
  }) async {
    final response = await _apiClient.authenticatedPostList(
      '/expense-account/$accountId/payments/all',
    );
    return response
        .map(ExpensePaymentResponseModel.fromJson)
        .toList(growable: false);
  }
}
