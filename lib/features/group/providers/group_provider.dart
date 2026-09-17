import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/preferences/app_preferences_service.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/get_group_model.response.dart';
import '../models/get_groups_model.response.dart';
import '../models/get_member_model.response.dart';
import '../models/group_model.response.dart';
import '../models/join_group_model.request.dart';
import '../models/join_group_model.response.dart';
import '../models/update_group_model.request.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService;
  final AppPreferencesService _preferencesService;

  GroupProvider(this._groupService, this._preferencesService);

  bool isLoading = false;
  bool _isInitialized = false;
  int _sessionVersion = 0;
  Future<void> _pendingPreferenceWrite = Future<void>.value();
  bool get isInitialized => _isInitialized;
  String? errorMessage;
  CreateGroupResponseModel? group;
  GroupResponseModel? updatedGroup;
  GetGroupsResponseModel? activeGroup;
  GetGroupResponseModel? groupDetails;
  List<GetGroupsResponseModel> groups = [];
  JoinGroupResponseModel? joinResponse;

  Future<void> resetSessionState() async {
    _sessionVersion++;
    isLoading = false;
    _isInitialized = false;
    errorMessage = null;
    group = null;
    updatedGroup = null;
    activeGroup = null;
    groupDetails = null;
    groups = [];
    joinResponse = null;
    notifyListeners();
    await _pendingPreferenceWrite;
  }

  Future<void> _saveActiveGroupId(int groupId) {
    final operation = _pendingPreferenceWrite.then(
      (_) => _preferencesService.saveActiveGroupId(groupId),
    );
    _pendingPreferenceWrite = operation.catchError((Object error) {
      debugPrint('No se pudo guardar el grupo activo: $error');
    });
    return operation;
  }

  Future<void> loadGroups() async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedGroups = await _groupService.getGroups();
      if (sessionVersion == _sessionVersion) groups = loadedGroups;
    } catch (error) {
      if (sessionVersion == _sessionVersion) {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createGroup({
    required String name,
    String? description,
    required bool shareLocationMandatorily,
  }) async {
    final sessionVersion = _sessionVersion;
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

      final createdGroup = await _groupService.createGroup(request: request);
      if (sessionVersion != _sessionVersion) return false;
      group = createdGroup;

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

  Future<bool> joinGroup({required String invitationCode}) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    joinResponse = null;

    notifyListeners();

    try {
      final request = JoinGroupRequest(invitationCode: invitationCode);

      final joinedGroup = await _groupService.joinGroup(request: request);
      if (sessionVersion != _sessionVersion) return false;
      joinResponse = joinedGroup;

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

  Future<bool> updateMemberRole({
    required int memberId,
    required RoleEnum role,
    required bool isCurrentUserAdmin,
  }) async {
    if (!isCurrentUserAdmin) {
      errorMessage = 'Solo los administradores pueden modificar los roles.';
      notifyListeners();

      return false;
    }

    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await _groupService.updateMemberRole(memberId: memberId, role: role);
      if (sessionVersion != _sessionVersion) return false;
      _applyUpdatedMemberRole(memberId, role);

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

    final sessionVersion = _sessionVersion;
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
      if (sessionVersion != _sessionVersion) return false;

      _applyUpdatedGroup(updatedGroup);

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

  void _applyUpdatedMemberRole(int memberId, RoleEnum role) {
    final currentGroup = groupDetails;

    if (currentGroup == null) {
      return;
    }

    final members = currentGroup.members.map((member) {
      if (member.id != memberId) {
        return member;
      }

      return GetMemberResponseModel(
        id: member.id,
        idUser: member.idUser,
        name: member.name,
        role: role,
      );
    }).toList();

    groupDetails = GetGroupResponseModel(
      id: currentGroup.id,
      name: currentGroup.name,
      description: currentGroup.description,
      shareLocationMandatorily: currentGroup.shareLocationMandatorily,
      invitationCode: currentGroup.invitationCode,
      members: members,
    );
  }

  Future<bool> getGroups() async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedGroups = await _groupService.getGroups();
      if (sessionVersion != _sessionVersion) return false;
      groups = loadedGroups;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      groups = [];
      activeGroup = null;

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final sessionVersion = _sessionVersion;
    final success = await getGroups();

    if (!success || sessionVersion != _sessionVersion) {
      return;
    }

    await _restoreActiveGroup();

    if (sessionVersion != _sessionVersion) return;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _restoreActiveGroup() async {
    final sessionVersion = _sessionVersion;
    if (groups.isEmpty) {
      activeGroup = null;
      groupDetails = null;
      try {
        await _preferencesService.clearActiveGroupId();
      } catch (error) {
        debugPrint('No se pudo limpiar el grupo activo guardado: $error');
      }
      return;
    }

    int? savedGroupId;
    try {
      savedGroupId = await _preferencesService.getActiveGroupId();
    } catch (error) {
      debugPrint('No se pudo leer el grupo activo guardado: $error');
    }
    if (sessionVersion != _sessionVersion) return;

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

    try {
      await _saveActiveGroupId(activeGroup!.id);
    } catch (error) {
      debugPrint('No se pudo guardar el grupo activo: $error');
    }
    if (sessionVersion != _sessionVersion) return;
    await getGroupDetails(groupId: activeGroup!.id);
  }

  Future<void> selectGroup(GetGroupsResponseModel group) async {
    if (!groups.any((current) => current.id == group.id)) return;
    final sessionVersion = _sessionVersion;
    activeGroup = group;
    groupDetails = null;

    try {
      await _saveActiveGroupId(group.id);
    } catch (error) {
      debugPrint('No se pudo guardar el grupo activo: $error');
    }
    if (sessionVersion != _sessionVersion) return;

    notifyListeners();

    await getGroupDetails(groupId: group.id);
  }

  Future<bool> getGroupDetails({required int groupId}) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedDetails = await _groupService.getGroup(groupId: groupId);
      if (sessionVersion != _sessionVersion) return false;
      groupDetails = loadedDetails;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      groupDetails = null;

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }
}
