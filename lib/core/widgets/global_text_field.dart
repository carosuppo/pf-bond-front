import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class GlobalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextAlign textAlign;

  const GlobalTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.inputFormatters,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: style ?? const TextStyle(color: AppColors.text),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mutedText),
        filled: true,
        fillColor: AppColors.fieldColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
