class JoinedGroupResponseModel {
  final int id;
  final String name;

  const JoinedGroupResponseModel({required this.id, required this.name});

  factory JoinedGroupResponseModel.fromJson(Map<String, dynamic> json) {
    return JoinedGroupResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class JoinGroupResponseModel {
  final String message;
  final JoinedGroupResponseModel group;
  final bool alreadyMember;

  const JoinGroupResponseModel({
    required this.message,
    required this.group,
    this.alreadyMember = false,
  });

  factory JoinGroupResponseModel.fromJson(
    Map<String, dynamic> json, {
    bool alreadyMember = false,
  }) {
    return JoinGroupResponseModel(
      message: json['message'] as String,
      group: JoinedGroupResponseModel.fromJson(
        json['group'] as Map<String, dynamic>,
      ),
      alreadyMember: alreadyMember,
    );
  }
}
