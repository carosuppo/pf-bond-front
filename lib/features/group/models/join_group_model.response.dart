class JoinGroupResponseModel {
  final String message;

  const JoinGroupResponseModel({required this.message});

  factory JoinGroupResponseModel.fromJson(Map<String, dynamic> json) {
    return JoinGroupResponseModel(message: json['message'] as String);
  }
}
