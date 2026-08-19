import 'package:flutter/material.dart';

/// A slow, gentle breathing scale+glow on an icon — used behind empty
/// states so a static "nothing here yet" screen still feels alive
/// instead of inert, without being distracting like a spinner would be.
class BreathingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color backgroundColor;

  const BreathingIcon({
    super.key,
    required this.icon,
    this.size = 64,
    this.iconSize = 32,
    required this.color,
    required this.backgroundColor,
  });

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<BreathingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1.0 + (0.06 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor,
              boxShadow: [
                BoxShadow(color: widget.color.withValues(alpha: 0.18 * t), blurRadius: 18 + (10 * t), spreadRadius: 1 + t),
              ],
            ),
            child: Icon(widget.icon, color: widget.color, size: widget.iconSize),
          ),
        );
      },
    );
  }
}
