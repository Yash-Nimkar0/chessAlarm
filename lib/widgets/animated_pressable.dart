import 'package:flutter/material.dart';

/// Wraps [child] with a subtle scale-down-on-press animation, giving
/// tactile feedback to any tappable element — especially bare
/// GestureDetector-based "buttons" throughout the app that don't get
/// InkWell's built-in ripple for free, and previously gave zero visual
/// response to a tap beyond whatever the tap itself triggered.
class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleOnPress;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleOnPress = 0.96,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // A plain GestureDetector's tap action lives on its own semantics
    // node, separate from any Text/Icon label inside `child` — without
    // merging them, assistive tech (and UI test tooling) sees an
    // unlabeled actionable node next to an inert label with no action,
    // instead of one "Rain, button"-style element.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget.onTap != null || widget.onLongPress != null,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? widget.scaleOnPress : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
