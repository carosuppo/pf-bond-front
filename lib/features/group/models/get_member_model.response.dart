enum RoleEnum { admin, member }

class GetMemberResponseModel {
  final int id;
  final int idUser;
  final String name;
  final String? profilePhoto;
  final RoleEnum role;

  const GetMemberResponseModel({
    required this.id,
    required this.idUser,
    required this.name,
    this.profilePhoto,
    required this.role,
  });

  factory GetMemberResponseModel.fromJson(Map<String, dynamic> json) {
    return GetMemberResponseModel(
      id: json['id'] as int,
      idUser: json['idUser'] as int,
      name: json['name'] as String,
      profilePhoto: json['profilePhoto'] as String?,
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
