class CreateGroupRequest {
  final String name;
  final String? description;
  final bool shareLocationMandatorily;

  const CreateGroupRequest({
    required this.name,
    this.description,
    required this.shareLocationMandatorily,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'shareLocationMandatorily': shareLocationMandatorily,
    };
  }
}
