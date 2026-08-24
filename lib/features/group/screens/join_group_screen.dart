import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/join_group_form.dart';

class JoinGroupScreen extends StatelessWidget {
  const JoinGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: JoinGroupForm(),
    );
  }
}
