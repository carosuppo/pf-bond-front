import '../../../core/network/api_client.dart';
import '../models/create_expense_account_model.request.dart';
import '../models/expense_account_model.response.dart';

class ExpenseAccountService {
  final ApiClient _apiClient;

  ExpenseAccountService(this._apiClient);

  Future<ExpenseAccountResponseModel> createExpenseAccount({
    required int groupId,
    required CreateExpenseAccountRequestModel request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group/$groupId/expense-account',
      request.toJson(),
    );
    return ExpenseAccountResponseModel.fromJson(response);
  }
}
