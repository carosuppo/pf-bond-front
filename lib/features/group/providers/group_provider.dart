import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/preferences/app_preferences_service.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/get_group_model.response.dart';
import '../models/get_groups_model.response.dart';
import '../models/group_model.response.dart';
import '../models/update_group_model.request.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService;
  final AppPreferencesService _preferencesService;

  GroupProvider(this._groupService, this._preferencesService);

  bool isLoading = false;
  bool _isInitialized = false;
  String? errorMessage;
  CreateGroupResponseModel? group;
  GroupResponseModel? updatedGroup;
  GetGroupsResponseModel? activeGroup;
  GetGroupResponseModel? groupDetails;
  List<GetGroupsResponseModel> groups = [];

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

      group = await _groupService.createGroup(request: request);

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
    required int groupId,
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

      final updatedGroup = await _groupService.updateGroup(
        groupId: groupId,
        request: request,
      );

      _applyUpdatedGroup(updatedGroup);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyUpdatedGroup(GroupResponseModel updated) {
    if (groupDetails != null && groupDetails!.id == updated.id) {
      groupDetails = GetGroupResponseModel(
        id: updated.id,
        name: updated.name,
        description: updated.description,
        shareLocationMandatorily: updated.shareLocationMandatorily,
        invitationCode: groupDetails!.invitationCode,
        members: groupDetails!.members,
      );
    }

    final index = groups.indexWhere((group) => group.id == updated.id);
    if (index != -1) {
      groups[index] = GetGroupsResponseModel(
        id: updated.id,
        name: updated.name,
      );
    }

    if (activeGroup != null && activeGroup!.id == updated.id) {
      activeGroup = GetGroupsResponseModel(id: updated.id, name: updated.name);
    }
  }

  Future<bool> getGroups() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      groups = await _groupService.getGroups();

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      groups = [];
      activeGroup = null;

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final success = await getGroups();

    if (!success) {
      return;
    }

    await _restoreActiveGroup();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _restoreActiveGroup() async {
    if (groups.isEmpty) {
      activeGroup = null;
      groupDetails = null;
      await _preferencesService.clearActiveGroupId();
      return;
    }

    final savedGroupId = await _preferencesService.getActiveGroupId();

    if (savedGroupId != null) {
      for (final group in groups) {
        if (group.id == savedGroupId) {
          activeGroup = group;
          groupDetails = null;
          await getGroupDetails(groupId: group.id);
          return;
        }
      }
    }

    final randomIndex = Random().nextInt(groups.length);
    activeGroup = groups[randomIndex];
    groupDetails = null;

    await _preferencesService.saveActiveGroupId(activeGroup!.id);
    await getGroupDetails(groupId: activeGroup!.id);
  }

  Future<void> selectGroup(GetGroupsResponseModel group) async {
    activeGroup = group;
    groupDetails = null;

    await _preferencesService.saveActiveGroupId(group.id);

    notifyListeners();

    await getGroupDetails(groupId: group.id);
  }

  Future<bool> getGroupDetails({required int groupId}) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      groupDetails = await _groupService.getGroup(groupId: groupId);

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      groupDetails = null;

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
