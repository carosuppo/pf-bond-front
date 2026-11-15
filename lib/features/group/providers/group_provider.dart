import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/preferences/app_preferences_service.dart';
import '../../profile/services/profile_photo_picker_service.dart';
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
import '../services/group_socket_service.dart';
import '../models/group_socket_event.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService;
  final AppPreferencesService _preferencesService;
  final ProfilePhotoPickerService _photoPickerService;

  GroupProvider(
    this._groupService,
    this._preferencesService, [
    ProfilePhotoPickerService? photoPickerService,
    this._groupSocket,
  ]) : _photoPickerService = photoPickerService ?? ProfilePhotoPickerService();

  final GroupSocketService? _groupSocket;
  StreamSubscription<GroupSocketEvent>? _socketSubscription;
  Future<void>? _syncFuture;
  Timer? _syncRetry;
  int _syncFailures = 0;
  int _detailsVersion = 0;
  int _groupsVersion = 0;
  bool _syncRequested = false;
  bool _fullSyncRequested = false;
  final Set<int> _changedGroupIds = <int>{};

  void _startGroupSocket() {
    if (_socketSubscription != null || _groupSocket == null) return;
    _socketSubscription = _groupSocket.events.listen(_onSocketEvent);
    unawaited(_groupSocket.connect());
  }

  void _onSocketEvent(GroupSocketEvent event) {
    if (!_isInitialized) return;
    _syncRetry?.cancel();
    _syncRequested = true;
    if (event is GroupSocketAuthenticated) {
      _fullSyncRequested = true;
    } else if (event is GroupsChanged) {
      _changedGroupIds.add(event.groupId);
    }
    _syncFuture ??= _drainSync(_sessionVersion);
  }

  Future<void> _drainSync(int version) async {
    try {
      while (_syncRequested && version == _sessionVersion) {
        _syncRequested = false;
        final bool full = _fullSyncRequested;
        final Set<int> changed = Set<int>.of(_changedGroupIds);
        _fullSyncRequested = false;
        _changedGroupIds.clear();
        try {
          final int groupsVersion = _groupsVersion;
          final List<GetGroupsResponseModel> loaded = await _groupService
              .getGroups();
          if (version != _sessionVersion) return;
          if (groupsVersion != _groupsVersion) {
            // A creation completed after this request started. Fetch again
            // instead of replacing the newly selected group with stale data.
            _syncRequested = true;
            _fullSyncRequested = true;
            continue;
          }
          final int? previousId = activeGroup?.id;
          groups = loaded;
          activeGroup = null;
          for (final GetGroupsResponseModel candidate in groups) {
            if (candidate.id == previousId) activeGroup = candidate;
          }
          activeGroup ??= groups.isEmpty ? null : groups.first;
          final int? activeId = activeGroup?.id;
          if (previousId != activeId || activeId == null) {
            ++_detailsVersion;
            groupDetails = null;
          }
          notifyListeners();
          if (full || activeId == null || previousId != activeId) {
            final Future<void> write = _pendingPreferenceWrite.then((_) async {
              if (version != _sessionVersion || activeGroup?.id != activeId) {
                return;
              }
              if (activeId == null) {
                await _preferencesService.clearActiveGroupId();
              } else {
                await _preferencesService.saveActiveGroupId(activeId);
              }
            });
            _pendingPreferenceWrite = write.catchError((Object error) {
              debugPrint('No se pudo persistir el grupo activo.');
            });
            await write;
          }
          if (version != _sessionVersion) return;
          if (activeId != null &&
              (full || previousId != activeId || changed.contains(activeId))) {
            final int detailsVersion = ++_detailsVersion;
            final GetGroupResponseModel details = await _groupService.getGroup(
              groupId: activeId,
            );
            if (version != _sessionVersion) return;
            if (activeGroup?.id == activeId &&
                detailsVersion == _detailsVersion) {
              groupDetails = details;
            }
          }
          _syncFailures = 0;
          errorMessage = null;
          notifyListeners();
        } catch (_) {
          // Retry this invalidation a bounded number of times; no background polling.
          if (version != _sessionVersion) return;
          if (++_syncFailures <= 3 && !_syncRequested) {
            _syncRetry = Timer(Duration(seconds: _syncFailures), () {
              if (version == _sessionVersion) {
                _onSocketEvent(const GroupSocketAuthenticated());
              }
            });
          }
        }
      }
    } finally {
      if (version == _sessionVersion) _syncFuture = null;
    }
  }

  @override
  void dispose() {
    ++_sessionVersion;
    _syncRetry?.cancel();
    unawaited(_socketSubscription?.cancel());
    unawaited(_groupSocket?.dispose());
    super.dispose();
  }

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
  XFile? selectedGroupImage;
  bool isSavingGroupImage = false;
  int? joinErrorStatusCode;

  Future<void> resetSessionState() async {
    _sessionVersion++;
    _syncRetry?.cancel();
    _syncFailures = 0;
    ++_detailsVersion;
    _syncRequested = false;
    _fullSyncRequested = false;
    _changedGroupIds.clear();
    _syncFuture = null;
    final Future<void>? cancelSubscription = _socketSubscription?.cancel();
    _socketSubscription = null;
    final Future<void>? disconnectSocket = _groupSocket?.disconnect();
    isLoading = false;
    _isInitialized = false;
    errorMessage = null;
    group = null;
    updatedGroup = null;
    activeGroup = null;
    groupDetails = null;
    groups = [];
    joinResponse = null;
    selectedGroupImage = null;
    isSavingGroupImage = false;
    joinErrorStatusCode = null;
    notifyListeners();
    await cancelSubscription;
    await disconnectSocket;
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
    final int groupsVersion = _groupsVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedGroups = await _groupService.getGroups();
      if (sessionVersion == _sessionVersion &&
          groupsVersion == _groupsVersion) {
        groups = loadedGroups;
      }
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
      final GetGroupsResponseModel summary = GetGroupsResponseModel(
        id: createdGroup.id,
        name: createdGroup.name,
        image: createdGroup.image,
      );
      ++_groupsVersion;
      groups = [
        for (final GetGroupsResponseModel current in groups)
          if (current.id != summary.id) current,
        summary,
      ];
      _isInitialized = true;
      await selectGroup(summary);
      if (sessionVersion != _sessionVersion) return false;
      _startGroupSocket();

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
    joinErrorStatusCode = null;

    notifyListeners();

    try {
      final request = JoinGroupRequest(invitationCode: invitationCode);

      final joinRequest = await _groupService.joinGroup(request: request);
      if (sessionVersion != _sessionVersion) return false;
      joinResponse = joinRequest;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      if (error is ApiException) {
        joinErrorStatusCode = error.statusCode;
        errorMessage = error.statusCode == 404
            ? 'No se pudo enviar la solicitud. Actualiza la aplicación y vuelve a intentarlo.'
            : error.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      }

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

  Future<bool> pickGroupImageFromGallery() async {
    return _pickGroupImage(_photoPickerService.pickFromGallery);
  }

  Future<bool> pickGroupImageFromCamera() async {
    return _pickGroupImage(_photoPickerService.pickFromCamera);
  }

  Future<bool> _pickGroupImage(Future<XFile?> Function() picker) async {
    errorMessage = null;

    try {
      final image = await picker();
      if (image == null) return false;
      selectedGroupImage = image;
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> saveGroupImage({
    required int groupId,
    required bool isCurrentUserAdmin,
  }) async {
    if (!isCurrentUserAdmin || selectedGroupImage == null) return false;

    isSavingGroupImage = true;
    errorMessage = null;
    notifyListeners();

    try {
      final updated = await _groupService.updateGroupImage(
        groupId: groupId,
        filePath: selectedGroupImage!.path,
        mimeType: selectedGroupImage!.mimeType,
      );
      _applyUpdatedGroup(updated);
      selectedGroupImage = null;
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSavingGroupImage = false;
      notifyListeners();
    }
  }

  void clearSelectedGroupImage() {
    if (selectedGroupImage == null) return;
    selectedGroupImage = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> removeMember({
    required int memberId,
    required bool isCurrentUserAdmin,
  }) async {
    if (!isCurrentUserAdmin) {
      errorMessage = 'Solo los administradores pueden expulsar miembros.';
      notifyListeners();

      return false;
    }

    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await _groupService.removeMember(memberId: memberId);
      if (sessionVersion != _sessionVersion) return false;
      _applyRemovedMember(memberId);

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

  Future<bool> deleteGroup({
    required int groupId,
    required bool isCurrentUserAdmin,
  }) async {
    if (!isCurrentUserAdmin) {
      errorMessage = 'Solo los administradores pueden eliminar el grupo.';
      notifyListeners();
      return false;
    }

    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _groupService.deleteGroup(groupId: groupId);
      if (sessionVersion != _sessionVersion) return false;
      _applyDeletedGroup(groupId);
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

  void handleGroupDeleted(int groupId) {
    _applyDeletedGroup(groupId);
    notifyListeners();
  }

  void _applyDeletedGroup(int groupId) {
    groups = groups.where((group) => group.id != groupId).toList();

    if (activeGroup?.id == groupId) {
      activeGroup = null;
      unawaited(_clearActiveGroupPreference(groupId));
    }

    if (groupDetails?.id == groupId) {
      groupDetails = null;
    }
  }

  Future<void> _clearActiveGroupPreference(int groupId) async {
    try {
      if (await _preferencesService.getActiveGroupId() == groupId) {
        await _preferencesService.clearActiveGroupId();
      }
    } catch (error) {
      debugPrint('No se pudo limpiar el grupo activo guardado: $error');
    }
  }

  Future<bool> leaveGroupForLocationPermission(int groupId) {
    return leaveGroup(groupId);
  }

  Future<bool> leaveGroup(int groupId) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _groupService.leaveGroup(groupId: groupId);
      if (sessionVersion != _sessionVersion) return false;

      groups = await _groupService.getGroups();
      if (sessionVersion != _sessionVersion) return false;

      if (activeGroup?.id == groupId || activeGroup == null) {
        groupDetails = null;
        activeGroup = groups.isEmpty ? null : groups.first;

        if (activeGroup == null) {
          try {
            await _preferencesService.clearActiveGroupId();
          } catch (error) {
            debugPrint('No se pudo limpiar el grupo activo guardado: $error');
          }
        } else {
          try {
            await _saveActiveGroupId(activeGroup!.id);
          } catch (error) {
            debugPrint('No se pudo guardar el grupo activo: $error');
          }
          if (sessionVersion != _sessionVersion) return false;

          try {
            groupDetails = await _groupService.getGroup(
              groupId: activeGroup!.id,
            );
          } catch (_) {
            groupDetails = null;
          }
        }
      }

      return true;
    } catch (_) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = 'No se pudo salir del grupo. Intentá de nuevo.';
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
        image: updated.image,
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
        image: updated.image,
      );
    }

    if (activeGroup != null && activeGroup!.id == updated.id) {
      activeGroup = GetGroupsResponseModel(
        id: updated.id,
        name: updated.name,
        image: updated.image,
      );
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
        profilePhoto: member.profilePhoto,
        role: role,
      );
    }).toList();

    groupDetails = GetGroupResponseModel(
      id: currentGroup.id,
      name: currentGroup.name,
      image: currentGroup.image,
      description: currentGroup.description,
      shareLocationMandatorily: currentGroup.shareLocationMandatorily,
      invitationCode: currentGroup.invitationCode,
      members: members,
    );
  }

  void _applyRemovedMember(int memberId) {
    final currentGroup = groupDetails;

    if (currentGroup == null) {
      return;
    }

    groupDetails = GetGroupResponseModel(
      id: currentGroup.id,
      name: currentGroup.name,
      image: currentGroup.image,
      description: currentGroup.description,
      shareLocationMandatorily: currentGroup.shareLocationMandatorily,
      invitationCode: currentGroup.invitationCode,
      members: currentGroup.members
          .where((member) => member.id != memberId)
          .toList(),
    );
  }

  Future<bool> getGroups() async {
    final sessionVersion = _sessionVersion;
    final int groupsVersion = _groupsVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedGroups = await _groupService.getGroups();
      if (sessionVersion != _sessionVersion) return false;
      if (groupsVersion != _groupsVersion) return true;
      groups = loadedGroups;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      if (groupsVersion != _groupsVersion) return true;
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
    if (_isInitialized) return;

    await _restoreActiveGroup();

    if (sessionVersion != _sessionVersion) return;
    _isInitialized = true;
    _startGroupSocket();
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
    ++_detailsVersion;
    bool needsSync = false;

    try {
      await _saveActiveGroupId(group.id);
    } catch (error) {
      debugPrint('No se pudo guardar el grupo activo: $error');
      needsSync = true;
    }
    if (sessionVersion != _sessionVersion || activeGroup?.id != group.id) {
      return;
    }

    notifyListeners();

    final bool loaded = await getGroupDetails(groupId: group.id);
    if (sessionVersion == _sessionVersion &&
        activeGroup?.id == group.id &&
        (needsSync || !loaded)) {
      // Creation remains successful even if a secondary operation fails.
      // Reuse the bounded REST reconciliation instead of repeating the POST.
      _onSocketEvent(const GroupSocketAuthenticated());
    }
  }

  Future<bool> refreshAndSelectGroup({required int groupId}) async {
    final sessionVersion = _sessionVersion;
    final loaded = await getGroups();
    if (!loaded || sessionVersion != _sessionVersion) {
      return false;
    }

    GetGroupsResponseModel? joinedGroup;
    for (final currentGroup in groups) {
      if (currentGroup.id == groupId) {
        joinedGroup = currentGroup;
        break;
      }
    }

    if (joinedGroup == null) {
      errorMessage = 'No se pudo encontrar el grupo de la invitación.';
      notifyListeners();
      return false;
    }

    await selectGroup(joinedGroup);
    if (sessionVersion != _sessionVersion || activeGroup?.id != groupId) {
      return false;
    }

    _isInitialized = true;
    _startGroupSocket();
    notifyListeners();
    return groupDetails?.id == groupId;
  }

  Future<bool> getGroupDetails({required int groupId}) async {
    final int detailsVersion = ++_detailsVersion;
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedDetails = await _groupService.getGroup(groupId: groupId);
      if (sessionVersion != _sessionVersion ||
          detailsVersion != _detailsVersion) {
        return false;
      }
      groupDetails = loadedDetails;

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion ||
          detailsVersion != _detailsVersion) {
        return false;
      }
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

  /// Obtiene los datos de un grupo para mostrar una cuenta sin cambiar el
  /// grupo activo ni el estado compartido de sus detalles.
  Future<GetGroupResponseModel?> getGroupDetailsForAccount({
    required int groupId,
  }) async {
    final sessionVersion = _sessionVersion;
    final currentDetails = groupDetails;
    if (currentDetails?.id == groupId) {
      return currentDetails;
    }

    final loadedDetails = await _groupService.getGroup(groupId: groupId);
    if (sessionVersion != _sessionVersion) {
      return null;
    }
    if (loadedDetails.id != groupId) {
      throw FormatException(
        'El grupo recibido no coincide con el grupo de la cuenta.',
      );
    }

    return loadedDetails;
  }
}
