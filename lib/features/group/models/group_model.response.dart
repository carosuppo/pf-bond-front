class GroupResponseModel {
  final String id;
  final String name;
  final String? description;
  final bool shareLocationMandatorily;

  const GroupResponseModel({
    required this.id,
    required this.name,
    this.description,
    required this.shareLocationMandatorily,
  });

  factory GroupResponseModel.fromJson(Map<String, dynamic> json) {
    return GroupResponseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
    );
  }
}
