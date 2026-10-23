import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/join_group_model.request.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _JoinApi extends ApiClient {
  _JoinApi() : super(SessionStorageService());

  Map<String, dynamic> response = {
    'message': 'Tu solicitud fue enviada correctamente.',
    'group': {'id': 12, 'name': 'Familia'},
  };
  ApiException? error;
  String? deletedPath;
  String? postedPath;
  String? listedPath;
  List<Map<String, dynamic>> listResponse = [];

  @override
  Future<Map<String, dynamic>> authenticatedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    postedPath = path;
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> authenticatedGetList(String path) async {
    listedPath = path;
    return listResponse;
  }

  @override
  Future<void> authenticatedDelete(String path) async {
    deletedPath = path;
  }
}

void main() {
  test(
    'maps the pending request returned by POST /group/join-request',
    () async {
      final api = _JoinApi();
      final response = await GroupService(
        api,
      ).joinGroup(request: const JoinGroupRequest(invitationCode: 'ABCDEF'));

      expect(api.postedPath, '/group/join-request');
      expect(response.message, 'Tu solicitud fue enviada correctamente.');
      expect(response.group.id, 12);
      expect(response.group.name, 'Familia');
      expect(response.alreadyMember, isFalse);
      expect(response.alreadyPending, isFalse);
    },
  );

  test(
    'maps only the member conflict that includes group information',
    () async {
      final api = _JoinApi()
        ..error = const ApiException(
          'Ya eres miembro de este grupo.',
          statusCode: 409,
          responseBody: {
            'message': 'Ya eres miembro de este grupo.',
            'group': {'id': 12, 'name': 'Familia'},
          },
        );

      final response = await GroupService(
        api,
      ).joinGroup(request: const JoinGroupRequest(invitationCode: 'ABCDEF'));

      expect(response.alreadyMember, isTrue);
      expect(response.group.id, 12);
    },
  );

  test('does not convert unrelated conflicts into successful joins', () async {
    final api = _JoinApi()
      ..error = const ApiException('Otro conflicto', statusCode: 409);

    await expectLater(
      GroupService(
        api,
      ).joinGroup(request: const JoinGroupRequest(invitationCode: 'ABCDEF')),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'uses the authenticated membership leave endpoint for the group',
    () async {
      final api = _JoinApi();

      await GroupService(api).leaveGroup(groupId: 12);

      expect(api.deletedPath, '/group/12/leave');
    },
  );

  test('uses the authenticated group deletion endpoint', () async {
    final api = _JoinApi();

    await GroupService(api).deleteGroup(groupId: 12);

    expect(api.deletedPath, '/group/12');
  });

  test(
    'loads join requests from the authenticated administrator inbox',
    () async {
      final api = _JoinApi()
        ..listResponse = [
          {
            'id': 22,
            'groupId': 3,
            'groupName': 'Familia',
            'requesterUserId': 7,
            'requesterName': 'Ana',
            'requesterProfilePhoto': null,
            'requestedAt': '2026-10-09T10:00:00.000Z',
          },
        ];

      final requests = await GroupService(api).getJoinRequests();

      expect(api.listedPath, '/group/join-requests/inbox');
      expect(requests.single.requesterName, 'Ana');
      expect(requests.single.groupName, 'Familia');
    },
  );

  test('accepts and rejects requests through their separate actions', () async {
    final api = _JoinApi();
    final service = GroupService(api);

    await service.acceptJoinRequest(requestId: 22);
    expect(api.postedPath, '/group/join-requests/22/accept');

    await service.rejectJoinRequest(requestId: 22);
    expect(api.postedPath, '/group/join-requests/22/reject');
  });
}
