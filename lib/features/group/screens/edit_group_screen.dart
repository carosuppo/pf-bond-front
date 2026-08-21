import 'package:flutter/material.dart';

import '../models/get_group_model.response.dart';
import '../widgets/edit_group_form.dart';

class EditGroupScreen extends StatelessWidget {
  final GetGroupResponseModel group;
  final bool isCurrentUserAdmin;

  const EditGroupScreen({
    super.key,
    required this.group,
    required this.isCurrentUserAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modificar grupo')),
      body: EditGroupForm(group: group, isCurrentUserAdmin: isCurrentUserAdmin),
    );
  }
}
