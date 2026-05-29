import 'package:flutter/material.dart';

/// Bright red used while a timer is running.
const Color kTimerRed = Color(0xFFFF1744);

/// A [Card] that shows a countdown fill when [progress] is non-null.
///
/// While active the banner is bright red, and the original [baseColor] fills
/// in from the right as [progress] goes 0 -> 1. When [progress] is null it
/// renders a plain card in [baseColor].
class TimerCard extends StatelessWidget {
  final Color? baseColor;
  final double? progress;
  final Widget child;

  const TimerCard({
    super.key,
    required this.child,
    this.baseColor,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A soft greyish-white glow to lift banners off the dark background.
    final shadowColor = isDark ? const Color(0x66FFFFFF) : null;
    final elevation = isDark ? 4.0 : null;

    if (progress == null) {
      return Card(
        color: baseColor,
        shadowColor: shadowColor,
        elevation: elevation,
        child: child,
      );
    }
    final base = baseColor ?? Theme.of(context).colorScheme.surface;
    final redWidth = (1 - progress!).clamp(0.0, 1.0);
    return Card(
      clipBehavior: Clip.antiAlias,
      shadowColor: shadowColor,
      elevation: elevation,
      child: Stack(
        children: [
          // Original colour underneath (revealed from the right as time passes).
          Positioned.fill(child: ColoredBox(color: base)),
          // Red shrinking from the left edge. The tween interpolates between
          // each 1-second tick so the shrink looks continuous, not stepped.
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1, end: redWidth),
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              builder: (_, value, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: const ColoredBox(color: kTimerRed),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
