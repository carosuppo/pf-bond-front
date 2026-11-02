import 'package:flutter/material.dart';

import '../widgets/create_event_form.dart';

class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const CreateEventForm());
  }
}
