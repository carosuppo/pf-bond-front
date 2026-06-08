class GroupModel {
  final int id;
  final String name;
  final bool shareUbicationMandatorily;

  GroupModel({
    required this.id,
    required this.name,
    required this.shareUbicationMandatorily,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    final shareValue =
        json['shareUbicationMandatorily'] ?? json['shareLocationMandatorily'];
    final bool shareUbicationMandatorily;

    if (shareValue is bool) {
      shareUbicationMandatorily = shareValue;
    } else if (shareValue is String) {
      shareUbicationMandatorily = shareValue.toLowerCase() == 'true';
    } else if (shareValue is int) {
      shareUbicationMandatorily = shareValue != 0;
    } else {
      shareUbicationMandatorily = false;
    }

    return GroupModel(
      id: json['id'] as int,
      name: json['name'] as String,
      shareUbicationMandatorily: shareUbicationMandatorily,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shareUbicationMandatorily': shareUbicationMandatorily,
    };
  }
}
