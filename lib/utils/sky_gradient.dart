import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// A continuous day-cycle gradient (night → dawn → day → dusk → night) used
/// as the "hero" background on the Home and Morning screens, so both feel
/// like part of one living sky rather than two unrelated static cards.
/// Interpolates between five key-frame stops by hour-of-day instead of
/// hard cutoffs, so the background actually shifts smoothly as time passes
/// rather than jumping at fixed hour boundaries.
class SkyGradient {
  static const List<_Stop> _stops = [
    _Stop(0, [AppTokens.nightBg, Color(0xFF1A1A3D)]), // midnight
    _Stop(5, [AppTokens.nightBg, AppTokens.dawnStart]), // pre-dawn
    _Stop(7, [AppTokens.dawnStart, AppTokens.dawnEnd]), // sunrise
    _Stop(10, [Color(0xFF5B9BD5), Color(0xFFFFD98E)]), // morning
    _Stop(15, [Color(0xFF4A90D9), Color(0xFFFFE9B8)]), // afternoon
    _Stop(18, [AppTokens.dawnEnd, Color(0xFF6A2B6E)]), // sunset
    _Stop(20, [Color(0xFF2D1B4E), AppTokens.nightBg]), // dusk
    _Stop(24, [AppTokens.nightBg, Color(0xFF1A1A3D)]), // midnight wrap
  ];

  static List<Color> colorsFor(DateTime time) {
    final hourFraction = time.hour + time.minute / 60.0;

    for (int i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i];
      final b = _stops[i + 1];
      if (hourFraction >= a.hour && hourFraction <= b.hour) {
        final t = (hourFraction - a.hour) / (b.hour - a.hour);
        return [
          Color.lerp(a.colors[0], b.colors[0], t)!,
          Color.lerp(a.colors[1], b.colors[1], t)!,
        ];
      }
    }
    return _stops.first.colors;
  }

  static bool isDay(DateTime time) => time.hour >= 6 && time.hour < 19;
}

class _Stop {
  final double hour;
  final List<Color> colors;
  const _Stop(this.hour, this.colors);
}
