import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofillHints,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffix,
    this.prefixIcon,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final IconData? prefixIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            AppLang.tr(label!),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: InputDesign.label,
              fontWeight: InputDesign.labelWeight,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator == null
              ? null
              : (val) {
                  final res = validator!(val);
                  return res == null ? null : AppLang.tr(res);
                },
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          autofillHints: autofillHints,
          maxLines: obscureText ? 1 : maxLines,
          inputFormatters: inputFormatters,
          style: Theme.of(context).textTheme.bodyLarge,
          cursorColor: InputDesign.cursor,
          decoration: InputDecoration(
            hintText: hint == null ? null : AppLang.tr(hint!),
            suffixIcon: suffix,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: InputDesign.prefixIcon, size: 20),
          ),
        ),
      ],
    );
  }
}
