import 'package:flutter/material.dart';

/// Helper to configure TextFormField with proper iOS keyboard handling.
/// 
/// Usage:
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(
///     labelText: 'Email',
///     hintText: 'your@email.com',
///   ),
///   textInputAction: TextInputAction.next,  // Or .done for last field
///   // ... rest of your configuration
/// )
/// ```
/// 
/// Key properties for iOS keyboard dismissal:
/// - `textInputAction: TextInputAction.done` (last field)
/// - `textInputAction: TextInputAction.next` (field before another)
/// - `onFieldSubmitted: (_) { FocusScope.of(context).nextFocus(); }`
/// 
/// The app also wraps screens with KeyboardDismisser which dismisses
/// keyboard when tapping outside text fields.

class TextInputConfig {
  /// Get the recommended textInputAction based on field position
  static TextInputAction actionFor({
    required bool isLastField,
  }) {
    return isLastField ? TextInputAction.done : TextInputAction.next;
  }

  /// Dismiss keyboard in current context
  static void dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Move focus to next field
  static void moveToNextField(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// Get common InputDecoration with proper styling
  static InputDecoration getInputDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      enabled: enabled,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
