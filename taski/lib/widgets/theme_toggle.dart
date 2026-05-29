import 'package:flutter/material.dart';
import 'package:taski/main.dart';

/// Wraps any widget so double-tapping it toggles light / dark theme.
/// Used on app-bar titles for a discoverable global gesture.
class ThemeToggleTap extends StatelessWidget {
  final Widget child;
  const ThemeToggleTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        appThemeMode.value = appThemeMode.value == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
      child: child,
    );
  }
}
