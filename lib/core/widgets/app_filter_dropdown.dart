import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppFilterOption<T> {
  const AppFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppFilterDropdown<T> extends StatelessWidget {
  const AppFilterDropdown({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final T selectedValue;
  final List<AppFilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final AppFilterOption<T> option in options) {
      if (option.value == selectedValue) {
        selectedLabel = option.label;
        break;
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return PopupMenuButton<T>(
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
          color: AppColors.cardColor,
          surfaceTintColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          enabled: enabled,
          onSelected: onSelected,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
            for (final AppFilterOption<T> option in options)
              PopupMenuItem<T>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),
          ],
          child: InputDecorator(
            decoration: _filterDecoration(label).copyWith(
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.mutedText,
              ),
            ),
            isEmpty: false,
            child: Text(
              selectedLabel ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}

InputDecoration _filterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
    floatingLabelStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
    filled: true,
    fillColor: AppColors.cardColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}
