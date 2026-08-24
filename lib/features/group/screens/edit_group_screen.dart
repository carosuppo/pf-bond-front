import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: EditGroupForm(group: group, isCurrentUserAdmin: isCurrentUserAdmin),
    );
  }
}
