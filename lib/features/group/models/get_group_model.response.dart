import 'get_member_model.response.dart';

class GetGroupResponseModel {
  final int id;
  final String name;
  final String? description;
  final bool shareLocationMandatorily;
  final String invitationCode;
  final List<GetMemberResponseModel> members;

  const GetGroupResponseModel({
    required this.id,
    required this.name,
    this.description,
    required this.shareLocationMandatorily,
    required this.invitationCode,
    required this.members,
  });

  factory GetGroupResponseModel.fromJson(Map<String, dynamic> json) {
    return GetGroupResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
      invitationCode: json['invitationCode'] as String,
      members: (json['members'] as List<dynamic>)
          .map(
            (member) =>
                GetMemberResponseModel.fromJson(member as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
