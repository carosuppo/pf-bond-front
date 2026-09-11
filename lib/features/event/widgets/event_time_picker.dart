import 'package:flutter/material.dart';

class EventTimePicker extends StatefulWidget {
  const EventTimePicker({
    super.key,
    required this.initialTime,
    required this.onChanged,
  });

  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<EventTimePicker> createState() => _EventTimePickerState();
}

class _EventTimePickerState extends State<EventTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;

  late final FixedExtentScrollController _hourController;

  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();

    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);

    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();

    super.dispose();
  }

  void _onHourChanged(int hour) {
    setState(() {
      _selectedHour = hour;
    });

    widget.onChanged(TimeOfDay(hour: hour, minute: _selectedMinute));
  }

  void _onMinuteChanged(int minute) {
    setState(() {
      _selectedMinute = minute;
    });

    widget.onChanged(TimeOfDay(hour: _selectedHour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Row(
        children: [
          Expanded(
            child: _TimeWheel(
              controller: _hourController,
              itemCount: 24,
              selectedValue: _selectedHour,
              onSelectedItemChanged: _onHourChanged,
            ),
          ),

          SizedBox(
            width: 40,
            child: Center(
              child: Text(':', style: Theme.of(context).textTheme.displaySmall),
            ),
          ),

          Expanded(
            child: _TimeWheel(
              controller: _minuteController,
              itemCount: 60,
              selectedValue: _selectedMinute,
              onSelectedItemChanged: _onMinuteChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.itemCount,
    required this.selectedValue,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedValue;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 64,
      diameterRatio: 2.2,
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final isSelected = index == selectedValue;

          final value = index.toString().padLeft(2, '0');

          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: theme.textTheme.displaySmall!.copyWith(
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.25),
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
              child: Text(value),
            ),
          );
        },
      ),
    );
  }
}
