import 'package:flutter/material.dart';

import '../widgets/create_group_form.dart';

class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),

      body: const CreateGroupForm(),
    );
  }
}
