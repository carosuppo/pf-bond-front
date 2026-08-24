import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/create_group_form.dart';

class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: const CreateGroupForm(),
    );
  }
}
