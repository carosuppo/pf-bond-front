import '../../../core/preferences/app_preferences_service.dart';
import '../providers/group_provider.dart';
import '../utils/invitation_code.dart';

enum GroupInvitationProcessingStatus {
  noPendingInvitation,
  requestSent,
  requestAlreadyPending,
  alreadyMember,
  authenticationRequired,
  invalidInvitation,
  retryableFailure,
}

class GroupInvitationProcessingResult {
  const GroupInvitationProcessingResult({
    required this.status,
    this.groupId,
    this.groupName,
    this.message,
  });

  final GroupInvitationProcessingStatus status;
  final int? groupId;
  final String? groupName;
  final String? message;

  bool get openedGroup =>
      status == GroupInvitationProcessingStatus.alreadyMember;
}

class GroupInvitationCoordinator {
  GroupInvitationCoordinator(this._preferences);

  final AppPreferencesService _preferences;
  Future<GroupInvitationProcessingResult>? _processing;

  Future<GroupInvitationProcessingResult> processPendingInvitation(
    GroupProvider groupProvider,
  ) async {
    final currentProcessing = _processing;
    if (currentProcessing != null) {
      return currentProcessing;
    }

    final processing = _processPendingInvitation(groupProvider);
    _processing = processing;

    try {
      return await processing;
    } finally {
      if (identical(_processing, processing)) {
        _processing = null;
      }
    }
  }

  Future<GroupInvitationProcessingResult> _processPendingInvitation(
    GroupProvider groupProvider,
  ) async {
    final pendingCode = await _preferences.getPendingInvitationCode();
    if (pendingCode == null) {
      return const GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.noPendingInvitation,
      );
    }

    final normalizedCode = InvitationCode.normalize(pendingCode);
    if (!InvitationCode.isValid(normalizedCode)) {
      await _preferences.clearPendingInvitationCode(expectedCode: pendingCode);
      return const GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.invalidInvitation,
        message: 'El enlace de invitación no es válido.',
      );
    }

    final joined = await groupProvider.joinGroup(
      invitationCode: normalizedCode,
    );
    if (!joined) {
      final statusCode = groupProvider.joinErrorStatusCode;
      if (statusCode == 400) {
        await _preferences.clearPendingInvitationCode(
          expectedCode: pendingCode,
        );
        return GroupInvitationProcessingResult(
          status: GroupInvitationProcessingStatus.invalidInvitation,
          message:
              groupProvider.errorMessage ??
              'La invitación ya no corresponde a un grupo vigente.',
        );
      }
      if (statusCode == 401) {
        return const GroupInvitationProcessingResult(
          status: GroupInvitationProcessingStatus.authenticationRequired,
          message: 'Tu sesión venció. Iniciá sesión para continuar.',
        );
      }

      return GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.retryableFailure,
        message:
            groupProvider.errorMessage ??
            'No se pudo procesar la invitación. Intentaremos nuevamente.',
      );
    }

    final response = groupProvider.joinResponse;
    if (response == null) {
      return const GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.retryableFailure,
        message: 'No se pudo identificar el grupo de la invitación.',
      );
    }

    if (response.alreadyMember) {
      final selected = await groupProvider.refreshAndSelectGroup(
        groupId: response.group.id,
      );
      if (!selected) {
        return GroupInvitationProcessingResult(
          status: GroupInvitationProcessingStatus.retryableFailure,
          message:
              groupProvider.errorMessage ??
              'No se pudo abrir el grupo al que ya perteneces.',
        );
      }
      await _preferences.clearPendingInvitationCode(expectedCode: pendingCode);
      return GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.alreadyMember,
        groupId: response.group.id,
        groupName: response.group.name,
        message: 'Ya pertenecés al grupo ${response.group.name}.',
      );
    }

    await _preferences.clearPendingInvitationCode(expectedCode: pendingCode);

    if (response.alreadyPending) {
      return GroupInvitationProcessingResult(
        status: GroupInvitationProcessingStatus.requestAlreadyPending,
        groupId: response.group.id,
        groupName: response.group.name,
        message: response.message,
      );
    }

    return GroupInvitationProcessingResult(
      status: GroupInvitationProcessingStatus.requestSent,
      groupId: response.group.id,
      groupName: response.group.name,
      message: response.message,
    );
  }
}
