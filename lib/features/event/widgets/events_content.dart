import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EventsContent extends StatelessWidget {
  const EventsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 88 : 112,
                      height: compact ? 88 : 112,
                      decoration: const BoxDecoration(
                        color: AppColors.fieldColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_rounded,
                        size: compact ? 44 : 56,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    const Text(
                      'Todavía no hay eventos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Usá el botón + para crear el primer\n'
                      'evento de este grupo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
