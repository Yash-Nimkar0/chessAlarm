import 'package:flutter/material.dart';

/// Animates an integer counting up (or down) from its previous value to
/// [value] whenever it changes, instead of just snapping to the new
/// number — used for streaks, points, and mission counts, the kind of
/// stat a user actually watches change after finishing a mission.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String Function(int)? formatter;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(formatter?.call(animatedValue) ?? '$animatedValue', style: style);
      },
    );
  }
}
