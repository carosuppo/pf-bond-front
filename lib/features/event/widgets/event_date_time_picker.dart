import 'package:flutter/material.dart';

import 'event_time_picker.dart';

enum EventDateTimePickerType { start, end }

class EventDateTimeResult {
  const EventDateTimeResult({required this.dateTime});

  final DateTime dateTime;
}

Future<EventDateTimeResult?> showEventDateTimePicker({
  required BuildContext context,
  required EventDateTimePickerType type,
  DateTime? initialDateTime,
  DateTime? startDateTime,
}) {
  return showDialog<EventDateTimeResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return _EventDateTimeDialog(
        type: type,
        initialDateTime: initialDateTime,
        startDateTime: startDateTime,
      );
    },
  );
}

enum _PickerStep { date, time }

class _EventDateTimeDialog extends StatefulWidget {
  const _EventDateTimeDialog({
    required this.type,
    this.initialDateTime,
    this.startDateTime,
  });

  final EventDateTimePickerType type;
  final DateTime? initialDateTime;
  final DateTime? startDateTime;

  @override
  State<_EventDateTimeDialog> createState() => _EventDateTimeDialogState();
}

class _EventDateTimeDialogState extends State<_EventDateTimeDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  _PickerStep _step = _PickerStep.date;

  String? _errorMessage;

  DateTime get _now => DateTime.now();

  bool get _isStart => widget.type == EventDateTimePickerType.start;

  @override
  void initState() {
    super.initState();

    final initialDateTime =
        widget.initialDateTime ?? widget.startDateTime ?? _now;

    _selectedDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );

    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);

    final minimumDate = _minimumDate;

    if (_selectedDate.isBefore(minimumDate)) {
      _selectedDate = minimumDate;
    }
  }

  DateTime get _minimumDate {
    if (!_isStart && widget.startDateTime != null) {
      final start = widget.startDateTime!;

      return DateTime(start.year, start.month, start.day);
    }

    final now = _now;

    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _maximumDate {
    final now = _now;

    return DateTime(now.year + 5, now.month, now.day);
  }

  DateTime get _selectedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  String _formatDate(DateTime dateTime) {
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];

    return '$weekday, ${dateTime.day} de $month';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatMonth(DateTime dateTime) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return '${months[dateTime.month - 1]} de ${dateTime.year}';
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _errorMessage = null;
      _step = _PickerStep.time;
    });
  }

  void _onTimeSelected(TimeOfDay time) {
    setState(() {
      _selectedTime = time;
      _errorMessage = null;
    });
  }

  String? _validate() {
    final selectedDateTime = _selectedDateTime;

    if (_isStart) {
      if (!selectedDateTime.isAfter(_now)) {
        return 'La fecha y hora de inicio deben ser posteriores a la fecha actual.';
      }

      return null;
    }

    final startDateTime = widget.startDateTime;

    if (startDateTime == null) {
      return null;
    }

    if (!selectedDateTime.isAfter(startDateTime)) {
      return 'La fecha y hora de finalización deben ser posteriores al inicio.';
    }

    return null;
  }

  void _confirm() {
    final error = _validate();

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });

      return;
    }

    Navigator.of(context).pop(EventDateTimeResult(dateTime: _selectedDateTime));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateTimeHeader(
                type: widget.type,
                selectedDate: _selectedDate,
                selectedTime: _selectedTime,
                startDateTime: widget.startDateTime,
                step: _step,
                formatDate: _formatDate,
                formatTime: _formatTime,
                onDateTap: () {
                  setState(() {
                    _step = _PickerStep.date;
                    _errorMessage = null;
                  });
                },
                onTimeTap: () {
                  setState(() {
                    _step = _PickerStep.time;
                    _errorMessage = null;
                  });
                },
              ),

              const SizedBox(height: 20),

              Divider(color: colorScheme.outlineVariant, height: 1),

              const SizedBox(height: 16),

              if (_step == _PickerStep.date)
                _buildDatePicker()
              else
                _buildTimePicker(),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorMessage(message: _errorMessage!),
              ],

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _step == _PickerStep.time ? _confirm : null,
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMonth(_selectedDate),
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 8),

        CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: _minimumDate,
          lastDate: _maximumDate,
          onDateChanged: _onDateSelected,
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return EventTimePicker(
      initialTime: _selectedTime,
      onChanged: _onTimeSelected,
    );
  }
}

class _DateTimeHeader extends StatelessWidget {
  const _DateTimeHeader({
    required this.type,
    required this.selectedDate,
    required this.selectedTime,
    required this.startDateTime,
    required this.step,
    required this.formatDate,
    required this.formatTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  final EventDateTimePickerType type;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final DateTime? startDateTime;
  final _PickerStep step;

  final String Function(DateTime) formatDate;
  final String Function(TimeOfDay) formatTime;

  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    final isStart = type == EventDateTimePickerType.start;

    if (isStart) {
      return _DateTimeHeaderValue(
        date: selectedDate,
        time: selectedTime,
        selected: true,
        dateSelected: step == _PickerStep.date,
        timeSelected: step == _PickerStep.time,
        formatDate: formatDate,
        formatTime: formatTime,
        onDateTap: onDateTap,
        onTimeTap: onTimeTap,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DateTimeHeaderValue(
            date: startDateTime!,
            time: TimeOfDay.fromDateTime(startDateTime!),
            selected: false,
            dateSelected: false,
            timeSelected: false,
            formatDate: formatDate,
            formatTime: formatTime,
            onDateTap: null,
            onTimeTap: null,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        Expanded(
          child: _DateTimeHeaderValue(
            date: selectedDate,
            time: selectedTime,
            selected: true,
            dateSelected: step == _PickerStep.date,
            timeSelected: step == _PickerStep.time,
            formatDate: formatDate,
            formatTime: formatTime,
            onDateTap: onDateTap,
            onTimeTap: onTimeTap,
          ),
        ),
      ],
    );
  }
}

class _DateTimeHeaderValue extends StatelessWidget {
  const _DateTimeHeaderValue({
    required this.date,
    required this.time,
    required this.selected,
    required this.dateSelected,
    required this.timeSelected,
    required this.formatDate,
    required this.formatTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  final DateTime date;
  final TimeOfDay time;

  final bool selected;
  final bool dateSelected;
  final bool timeSelected;

  final String Function(DateTime) formatDate;
  final String Function(TimeOfDay) formatTime;

  final VoidCallback? onDateTap;
  final VoidCallback? onTimeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        GestureDetector(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: dateSelected
                ? BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  )
                : null,
            child: Text(
              formatDate(date),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: dateSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        GestureDetector(
          onTap: onTimeTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: timeSelected
                ? BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  )
                : null,
            child: Text(
              formatTime(time),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: timeSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
