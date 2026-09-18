import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../group/widgets/group_selector_button.dart';
import '../widgets/events_content.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  void _goToCreateEvent(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.createEvent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Positioned.fill(top: 64, child: EventsContent()),
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: GroupSelectorButton(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        highlightElevation: 12,
        onPressed: () => _goToCreateEvent(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
