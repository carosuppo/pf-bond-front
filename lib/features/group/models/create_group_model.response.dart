class CreateGroupResponseModel {
  final int id;
  final String name;
  final String? image;
  final String? description;
  final bool shareLocationMandatorily;
  final String invitationCode;

  const CreateGroupResponseModel({
    required this.id,
    required this.name,
    this.image,
    this.description,
    required this.shareLocationMandatorily,
    required this.invitationCode,
  });

  factory CreateGroupResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateGroupResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      image: json['image'] as String?,
      description: json['description'] as String?,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
      invitationCode: json['invitationCode'] as String,
    );
  }
}
