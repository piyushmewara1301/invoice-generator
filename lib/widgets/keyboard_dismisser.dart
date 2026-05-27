import 'package:flutter/material.dart';

/// Widget that dismisses the keyboard when tapping outside of text fields.
/// Wrap your entire app or screen with this to enable keyboard dismissal on tap.
class KeyboardDismisser extends StatelessWidget {
  final Widget child;

  const KeyboardDismisser({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      onVerticalDragStart: (_) => _dismissKeyboard(),
      onHorizontalDragStart: (_) => _dismissKeyboard(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
