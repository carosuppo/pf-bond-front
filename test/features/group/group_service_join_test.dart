import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/join_group_model.request.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _JoinApi extends ApiClient {
  _JoinApi() : super(SessionStorageService());

  Map<String, dynamic> response = {
    'message': 'Ingresaste al grupo correctamente.',
    'group': {'id': 12, 'name': 'Familia'},
  };
  ApiException? error;

  @override
  Future<Map<String, dynamic>> authenticatedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return response;
  }
}

void main() {
  test('maps the joined group returned by POST /group/join', () async {
    final response = await GroupService(
      _JoinApi(),
    ).joinGroup(request: const JoinGroupRequest(invitationCode: 'ABCDEF'));

    expect(response.message, 'Ingresaste al grupo correctamente.');
    expect(response.group.id, 12);
    expect(response.group.name, 'Familia');
    expect(response.alreadyMember, isFalse);
  });

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
}
