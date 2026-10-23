import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

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

  void _onHourTyped(int hour) {
    _hourController.jumpToItem(hour);
    _onHourChanged(hour);
  }

  void _onMinuteTyped(int minute) {
    _minuteController.jumpToItem(minute);
    _onMinuteChanged(minute);
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
              onValueTyped: _onHourTyped,
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
              onValueTyped: _onMinuteTyped,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required this.controller,
    required this.itemCount,
    required this.selectedValue,
    required this.onSelectedItemChanged,
    required this.onValueTyped,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedValue;
  final ValueChanged<int> onSelectedItemChanged;
  final ValueChanged<int> onValueTyped;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  bool _editing = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _textController.text = widget.selectedValue.toString().padLeft(2, '0');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _finishEditing() {
    if (!_editing) return;
    final parsed = int.tryParse(_textController.text);
    _focusNode.unfocus();
    setState(() => _editing = false);
    if (parsed != null && parsed >= 0 && parsed < widget.itemCount) {
      if (parsed != widget.selectedValue) {
        widget.onValueTyped(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: widget.controller,
      itemExtent: 64,
      diameterRatio: 2.2,
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        if (_editing) {
          setState(() => _editing = false);
          _focusNode.unfocus();
        }
        widget.onSelectedItemChanged(index);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.itemCount,
        builder: (context, index) {
          final isSelected = index == widget.selectedValue;

          final value = index.toString().padLeft(2, '0');

          if (isSelected && _editing) {
            return Center(
              child: SizedBox(
                width: 80,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _finishEditing(),
                  onEditingComplete: _finishEditing,
                  onTapOutside: (_) => _finishEditing(),
                ),
              ),
            );
          }

          return Center(
            child: GestureDetector(
              onTap: isSelected ? _startEditing : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  color: isSelected
                      ? AppColors.text
                      : AppColors.text.withValues(alpha: 0.25),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
                child: Text(value),
              ),
            ),
          );
        },
      ),
    );
  }
}
