class CreateGroupResponseModel {
  final String id;
  final String name;
  final String? description;
  final bool shareLocationMandatorily;
  final String invitationCode;

  const CreateGroupResponseModel({
    required this.id,
    required this.name,
    this.description,
    required this.shareLocationMandatorily,
    required this.invitationCode,
  });

  factory CreateGroupResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateGroupResponseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
      invitationCode: json['invitationCode'] as String,
    );
  }
}
