import 'get_member_model.response.dart';

class UpdateMemberRoleRequest {
  final RoleEnum role;

  const UpdateMemberRoleRequest({required this.role});

  Map<String, dynamic> toJson() {
    return {'role': role == RoleEnum.admin ? 'ADMIN' : 'MEMBER'};
  }
}
