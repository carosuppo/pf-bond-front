class GetGroupsResponseModel {
  final int id;
  final String name;

  GetGroupsResponseModel({required this.id, required this.name});

  factory GetGroupsResponseModel.fromJson(Map<String, dynamic> json) {
    return GetGroupsResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
