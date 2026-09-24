import '../../../core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/get_group_model.response.dart';
import '../models/get_member_info_model.response.dart';
import '../models/get_groups_model.response.dart';
import '../models/get_member_model.response.dart';
import '../models/group_model.response.dart';
import '../models/join_group_model.request.dart';
import '../models/join_group_model.response.dart';
import '../models/update_group_model.request.dart';
import '../models/update_member_role_model.request.dart';

class GroupService {
  final ApiClient _apiClient;

  GroupService(this._apiClient);

  Future<CreateGroupResponseModel> createGroup({
    required CreateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group',
      request.toJson(),
    );
    return CreateGroupResponseModel.fromJson(response);
  }

  Future<JoinGroupResponseModel> joinGroup({
    required JoinGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group/join',
      request.toJson(),
    );

    return JoinGroupResponseModel.fromJson(response);
  }

  Future<GroupResponseModel> updateGroup({
    required int groupId,
    required UpdateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPut(
      '/group/$groupId',
      request.toJson(),
    );
    return GroupResponseModel.fromJson(response);
  }

  Future<GroupResponseModel> updateGroupImage({
    required int groupId,
    required String filePath,
    String? mimeType,
  }) async {
    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: _imageMediaType(filePath, mimeType),
    );
    final response = await _apiClient.authenticatedMultipartPatch(
      '/group/$groupId/image',
      file: file,
    );

    return GroupResponseModel.fromJson(response);
  }

  Future<void> updateMemberRole({
    required int memberId,
    required RoleEnum role,
  }) async {
    final request = UpdateMemberRoleRequest(role: role);

    await _apiClient.authenticatedPut(
      '/member/$memberId/role',
      request.toJson(),
    );
  }

  Future<void> removeMember({required int memberId}) async {
    await _apiClient.authenticatedDelete('/member/$memberId');
  }

  Future<List<GetGroupsResponseModel>> getGroups() async {
    final response = await _apiClient.authenticatedGetList('/group');

    return response.map(GetGroupsResponseModel.fromJson).toList();
  }

  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    final response = await _apiClient.authenticatedGet('/group/$groupId');

    return GetGroupResponseModel.fromJson(response);
  }

  Future<GetMemberInfoResponseModel> getMemberInfo({
    required int memberId,
  }) async {
    final response = await _apiClient.authenticatedGet('/member/$memberId');

    return GetMemberInfoResponseModel.fromJson(response);
  }

  MediaType _imageMediaType(String filePath, String? mimeType) {
    final normalizedMimeType = mimeType?.toLowerCase();

    if (normalizedMimeType == 'image/jpg' ||
        normalizedMimeType == 'image/jpeg') {
      return MediaType('image', 'jpeg');
    }

    if (normalizedMimeType == 'image/png') {
      return MediaType('image', 'png');
    }

    if (normalizedMimeType == 'image/webp') {
      return MediaType('image', 'webp');
    }

    return switch (filePath.toLowerCase().split('.').last) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('application', 'octet-stream'),
    };
  }
}
