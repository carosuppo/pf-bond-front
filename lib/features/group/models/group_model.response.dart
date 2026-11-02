class GroupResponseModel {
  final int id;
  final String name;
  final String? image;
  final String? description;
  final bool shareLocationMandatorily;

  const GroupResponseModel({
    required this.id,
    required this.name,
    this.image,
    this.description,
    required this.shareLocationMandatorily,
  });

  factory GroupResponseModel.fromJson(Map<String, dynamic> json) {
    return GroupResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      image: json['image'] as String?,
      description: json['description'] as String?,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
    );
  }
}
