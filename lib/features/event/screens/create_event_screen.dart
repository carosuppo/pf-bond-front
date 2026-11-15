import 'package:flutter/material.dart';

import '../widgets/create_event_form.dart';

class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: CreateEventForm(initialStartDate: initialDate));
  }
}
