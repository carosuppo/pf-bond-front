import 'package:flutter/material.dart';

import '../models/event_model.response.dart';
import '../widgets/create_event_form.dart';

class EditEventScreen extends StatelessWidget {
  final EventResponseModel event;
  final int groupId;

  const EditEventScreen({
    super.key,
    required this.event,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CreateEventForm(initialEvent: event, groupId: groupId),
    );
  }
}
