class GetGroupsResponseModel {
  final int id;
  final String name;
  final String? image;

  GetGroupsResponseModel({required this.id, required this.name, this.image});

  factory GetGroupsResponseModel.fromJson(Map<String, dynamic> json) {
    return GetGroupsResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      image: json['image'] as String?,
    );
  }
}
