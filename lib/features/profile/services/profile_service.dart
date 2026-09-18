import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';
import '../models/update_profile_request.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  Future<UserModel> getCurrentUser() async {
    final json = await _apiClient.authenticatedGet('/user/me');

    return UserModel.fromJson(json);
  }

  Future<UserModel> updateCurrentUser(UpdateProfileRequest request) async {
    final json = await _apiClient.authenticatedPatch(
      '/user/me',
      request.toJson(),
    );

    return UserModel.fromJson(json);
  }

  Future<UserModel> updateProfilePhoto(
    String filePath, {
    String? mimeType,
  }) async {
    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: _profilePhotoMediaType(filePath, mimeType),
    );
    final json = await _apiClient.authenticatedMultipartPatch(
      '/user/profile-photo',
      file: file,
    );

    return UserModel.fromJson(json);
  }

  MediaType _profilePhotoMediaType(String filePath, String? mimeType) {
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

    final extension = filePath.toLowerCase().split('.').last;

    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('application', 'octet-stream'),
    };
  }
}
