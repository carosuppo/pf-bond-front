import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/timezone/app_timezone.dart';
import '../models/create_event_model.request.dart';

class EventRecurrenceFields extends StatelessWidget {
  final EventRecurrenceRequest? value;
  final DateTime? startAt;
  final bool enabled;
  final ValueChanged<EventRecurrenceRequest?> onChanged;

  const EventRecurrenceFields({
    super.key,
    required this.value,
    required this.startAt,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _selectUntil(BuildContext context) async {
    final DateTime base = startAt ?? AppTimezone.now();
    final DateTime first = DateTime(base.year, base.month, base.day + 1);
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: value?.until != null && !value!.until!.isBefore(first)
          ? value!.until!
          : first,
      firstDate: first,
      lastDate: DateTime(first.year + 100, 12, 31),
    );
    if (selected == null || !context.mounted) return;
    onChanged(
      EventRecurrenceRequest(
        frequency: value!.frequency,
        until: DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Repetir evento'),
        value: value != null,
        onChanged: enabled
            ? (bool selected) => onChanged(
                selected
                    ? const EventRecurrenceRequest(
                        frequency: EventRecurrenceFrequency.weekly,
                      )
                    : null,
              )
            : null,
      ),
      if (value != null)
        Material(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<EventRecurrenceFrequency>(
                  initialValue: value!.frequency,
                  borderRadius: BorderRadius.circular(20),
                  decoration: InputDecoration(
                    labelText: 'Periodicidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  items: EventRecurrenceFrequency.values
                      .map(
                        (EventRecurrenceFrequency frequency) =>
                            DropdownMenuItem<EventRecurrenceFrequency>(
                              value: frequency,
                              child: Text(frequency.label),
                            ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (EventRecurrenceFrequency? frequency) {
                          if (frequency != null) {
                            onChanged(
                              EventRecurrenceRequest(
                                frequency: frequency,
                                until: value!.until,
                              ),
                            );
                          }
                        }
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repetir hasta (opcional)'),
                  subtitle: Text(
                    value!.until == null
                        ? 'Sin fecha final: el evento continuará repitiéndose.'
                        : '${value!.until!.day}/${value!.until!.month}/${value!.until!.year}',
                  ),
                  onTap: enabled ? () => _selectUntil(context) : null,
                  trailing: value!.until == null
                      ? const Icon(Icons.calendar_today)
                      : IconButton(
                          tooltip: 'Quitar fecha final',
                          icon: const Icon(Icons.clear),
                          onPressed: enabled
                              ? () => onChanged(
                                  EventRecurrenceRequest(
                                    frequency: value!.frequency,
                                  ),
                                )
                              : null,
                        ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
