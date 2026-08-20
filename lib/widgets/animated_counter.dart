import 'package:flutter/material.dart';

/// Animates an integer counting up (or down) from its previous value to
/// [value] whenever it changes, instead of just snapping to the new
/// number — used for streaks, points, and mission counts, the kind of
/// stat a user actually watches change after finishing a mission.
///
/// [delay] optionally holds the count-up at 0 before starting, so a group
/// of these shown together (e.g. a weekly recap) can stagger — each stat
/// ticking up a beat after the last, instead of all counting in lockstep.
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final String Function(int)? formatter;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.formatter,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  late int _target;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _target = widget.value;
    } else {
      _target = 0;
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _target = widget.value);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A later value change (e.g. after a mission completes) should count up
    // right away - the delay is only ever for the initial stagger-in.
    if (widget.value != oldWidget.value) {
      _target = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: _target),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(widget.formatter?.call(animatedValue) ?? '$animatedValue', style: widget.style);
      },
    );
  }
}
