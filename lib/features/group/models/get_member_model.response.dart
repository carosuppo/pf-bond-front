enum RoleEnum { admin, member }

class GetMemberResponseModel {
  final int idUser;
  final String name;
  final RoleEnum role;

  const GetMemberResponseModel({
    required this.idUser,
    required this.name,
    required this.role,
  });

  factory GetMemberResponseModel.fromJson(Map<String, dynamic> json) {
    return GetMemberResponseModel(
      idUser: json['idUser'] as int,
      name: json['name'] as String,
      role: _roleFromJson(json['role'] as String),
    );
  }

  static RoleEnum _roleFromJson(String role) {
    switch (role) {
      case 'ADMIN':
        return RoleEnum.admin;
      case 'MEMBER':
        return RoleEnum.member;
      default:
        throw FormatException('Rol de miembro desconocido: $role');
    }
  }
}
