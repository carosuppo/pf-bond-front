import 'package:flutter/material.dart';

import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/group_model.response.dart';
import '../models/update_group_model.request.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService;

  GroupProvider(this._groupService);

  bool isLoading = false;
  String? errorMessage;

  List<GroupResponseModel> groups = [];

  CreateGroupResponseModel? group;
  GroupResponseModel? updatedGroup;

  Future<void> loadGroups() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      groups = await _groupService.getGroups();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    String? description,
    required bool shareLocationMandatorily,
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

      group = await _groupService.createGroup(
        request: request,
      );

      groups = await _groupService.getGroups();

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup({
    required String groupId,
    required String name,
    String? description,
    required bool shareLocationMandatorily,
    required bool isCurrentUserAdmin,
  }) async {
    if (!isCurrentUserAdmin) {
      errorMessage = 'Solo los administradores pueden modificar el grupo.';
      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    updatedGroup = null;

    notifyListeners();

    try {
      final request = UpdateGroupRequest(
        name: name,
        description: description,
        shareLocationMandatorily: shareLocationMandatorily,
      );

      updatedGroup = await _groupService.updateGroup(
        groupId: groupId,
        request: request,
      );

      groups = await _groupService.getGroups();

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

