import 'package:flutter/material.dart';

import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService;

  GroupProvider(this._groupService);

  bool isLoading = false;
  String? errorMessage;
  CreateGroupResponseModel? group;

  Future<bool> createGroup({
    required String name,
    String? description,
    required bool shareLocationMandatorily,
    required int userId,
  }) async {
    isLoading = true;
    errorMessage = null;
    group = null;

    notifyListeners();

    try {
      final request = CreateGroupRequest(
        name: name,
        description: description,
        shareLocationMandatorily: shareLocationMandatorily,
      );

      group = await _groupService.createGroup(request: request, userId: userId);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
