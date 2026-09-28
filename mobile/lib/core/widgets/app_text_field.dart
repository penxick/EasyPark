import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.labelIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autovalidateMode = AutovalidateMode.disabled,
  });
  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText, errorText, helperText;
  final IconData? prefixIcon;
  final IconData? labelIcon;
  final Widget? suffix;
  final bool obscureText, enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged, onSubmitted;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, size: 16),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, style: AppTypography.title)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            validator: validator,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            autovalidateMode: autovalidateMode,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: hintText,
              errorText: errorText,
              helperText: helperText,
              helperMaxLines: 4,
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(
                      prefixIcon,
                      size: 20,
                      color: AppColors.mutedForeground,
                    ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    ),
  );
}
