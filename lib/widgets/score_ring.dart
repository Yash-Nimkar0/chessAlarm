import 'package:flutter/material.dart';

/// A circular gauge that animates its fill in from zero the first time
/// it's built — used anywhere a 0-100-style score needs to read as more
/// than a plain number (sleep score, mission stats). The number counts
/// up in lockstep with the ring so the two never look disconnected.
class ScoreRing extends StatelessWidget {
  final int score;
  final int max;
  final double size;
  final double strokeWidth;
  final Color ringColor;
  final Color trackColor;
  final Color textColor;
  final TextStyle? numberStyle;
  final String? suffix;

  const ScoreRing({
    super.key,
    required this.score,
    this.max = 100,
    this.size = 84,
    this.strokeWidth = 8,
    this.ringColor = Colors.white,
    this.trackColor = const Color(0x2EFFFFFF),
    this.textColor = Colors.white,
    this.numberStyle,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: fraction),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: strokeWidth,
                  color: trackColor,
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(ringColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * max).round()}',
                    style: numberStyle ?? TextStyle(color: textColor, fontSize: size * 0.28, fontWeight: FontWeight.w900),
                  ),
                  if (suffix != null)
                    Text(
                      suffix!,
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: size * 0.11, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
