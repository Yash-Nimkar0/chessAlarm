import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum _Ambience { clearDay, clearNight, cloudyDay, cloudyNight, fog, rain, snow, storm }

_Ambience _ambienceFor(int weatherCode, bool isDay) {
  if (weatherCode >= 95) return _Ambience.storm;
  if (weatherCode >= 71 && weatherCode <= 77) return _Ambience.snow;
  if ((weatherCode >= 51 && weatherCode <= 67) || (weatherCode >= 80 && weatherCode <= 82)) return _Ambience.rain;
  if (weatherCode >= 45 && weatherCode <= 48) return _Ambience.fog;
  if (weatherCode >= 1 && weatherCode <= 3) return isDay ? _Ambience.cloudyDay : _Ambience.cloudyNight;
  return isDay ? _Ambience.clearDay : _Ambience.clearNight;
}

/// How hard it's coming down, 0..1 - drives raindrop count/speed so a
/// drizzle and a downpour don't look identical.
double _rainIntensity(int weatherCode) {
  if (weatherCode == 65 || weatherCode == 82 || weatherCode == 67) return 1.0;
  if (weatherCode == 63 || weatherCode == 81) return 0.6;
  return 0.35;
}

/// A full-card, weather-aware continuous animation - not a generic star
/// field regardless of conditions. Rain actually falls continuously (not a
/// one-off streak), snow drifts down and sways, clouds drift steadily in one
/// direction and wrap around instead of rocking back and forth, storms flash,
/// and clear skies keep the twinkling stars / shooting stars / light motes.
///
/// [t] drives everything on the fast (8s) cycle; [tCloud] drives cloud drift
/// on its own slower cycle. Both are 0..1 loop fractions. Anything using a
/// `(t * speed + phase) % 1.0` position formula MUST use an integer `speed`
/// - a fractional speed means the position at t=1 (just before the
/// controller wraps back to t=0) doesn't match the position at t=0, so the
/// element visibly jumps/teleports every loop instead of wrapping
/// seamlessly. That was a real bug here: clouds/rain/snow all used
/// fractional speeds and visibly "hitched" every 8 seconds.
class WeatherAmbiencePainter extends CustomPainter {
  final double t;
  final double tCloud;
  final int weatherCode;
  final bool isDay;

  WeatherAmbiencePainter({required this.t, required this.tCloud, required this.weatherCode, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    final ambience = _ambienceFor(weatherCode, isDay);
    switch (ambience) {
      case _Ambience.clearNight:
        _paintStars(canvas, size, vivid: true);
        break;
      case _Ambience.clearDay:
        _paintLightMotes(canvas, size);
        break;
      case _Ambience.cloudyDay:
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.55), layers: 3);
        _paintLightMotes(canvas, size, count: 6);
        break;
      case _Ambience.cloudyNight:
        _paintStars(canvas, size, vivid: false);
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.16), layers: 2);
        break;
      case _Ambience.fog:
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.28), layers: 4, wide: true);
        break;
      case _Ambience.rain:
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.22), layers: 2);
        _paintRain(canvas, size, intensity: _rainIntensity(weatherCode));
        break;
      case _Ambience.snow:
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.2), layers: 2);
        _paintSnow(canvas, size);
        break;
      case _Ambience.storm:
        _paintDriftingClouds(canvas, size, color: Colors.white.withValues(alpha: 0.18), layers: 2);
        _paintRain(canvas, size, intensity: 1.0);
        _paintLightningFlash(canvas, size);
        break;
    }
  }

  // --- Clear sky: stars + occasional shooting stars (unchanged rhythm) ---
  void _paintStars(Canvas canvas, Size size, {required bool vivid}) {
    final random = math.Random(7);
    final count = vivid ? 46 : 22;
    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final phase = random.nextDouble();
      final radius = 0.6 + random.nextDouble() * 1.4;
      final twinkle = (math.sin((t + phase) * math.pi * 2) + 1) / 2;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.15 + twinkle * 0.55);
      canvas.drawCircle(Offset(baseX, baseY), radius, paint);
    }
    if (vivid) _paintShootingStars(canvas, size);
  }

  void _paintShootingStars(Canvas canvas, Size size) {
    for (final seed in [11, 41]) {
      final random = math.Random(seed);
      final startDelay = random.nextDouble() * 0.6;
      const flightDuration = 0.18;
      final localT = (t - startDelay) % 1.0;
      if (localT < 0 || localT > flightDuration) continue;

      final progress = localT / flightDuration;
      final startX = size.width * (0.15 + random.nextDouble() * 0.5);
      final startY = size.height * (0.05 + random.nextDouble() * 0.2);
      const angle = 0.55;
      final travel = size.width * 0.5;

      final headX = startX + math.cos(angle) * travel * progress;
      final headY = startY + math.sin(angle) * travel * progress;
      final tailX = headX - math.cos(angle) * travel * 0.25;
      final tailY = headY - math.sin(angle) * travel * 0.25;

      final fade = math.sin(progress * math.pi);
      final trailPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(tailX, tailY),
          Offset(headX, headY),
          [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.9 * fade)],
        )
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), trailPaint);
      canvas.drawCircle(Offset(headX, headY), 1.6, Paint()..color = Colors.white.withValues(alpha: fade));
    }
  }

  // --- Clear day: soft floating light motes ---
  void _paintLightMotes(Canvas canvas, Size size, {int count = 14}) {
    final random = math.Random(3);
    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final phase = random.nextDouble();
      final radius = 1.5 + random.nextDouble() * 2.5;
      final twinkle = (math.sin((t + phase) * math.pi * 2) + 1) / 2;
      final drift = math.sin((t + phase) * math.pi * 2) * 6;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.08 + twinkle * 0.18);
      canvas.drawCircle(Offset(baseX + drift, baseY), radius, paint);
    }
  }

  // --- Clouds: slow, seamless one-direction drift that WRAPS, never
  // oscillates. Runs on tCloud (its own ~28s cycle) with an INTEGER speed
  // per layer so position(tCloud=1) == position(tCloud=0) exactly - no jump
  // at the loop boundary - while still giving back layers a slower drift
  // than front layers for parallax depth.
  void _paintDriftingClouds(Canvas canvas, Size size, {required Color color, int layers = 3, bool wide = false}) {
    for (int layer = 0; layer < layers; layer++) {
      final random = math.Random(100 + layer);
      final speed = layer + 1; // integer: 1, 2, 3... whole sweeps per cycle
      final puffW = size.width * (wide ? 0.75 : (0.42 + layer * 0.12));
      final y = size.height * (0.15 + layer * 0.28 + random.nextDouble() * 0.1);
      final wrapWidth = size.width + puffW * 2;
      final localT = (tCloud * speed + random.nextDouble()) % 1.0;
      final x = -puffW + localT * wrapWidth;
      final opacity = color.a * (wide ? 1.0 : (1.0 - layer * 0.22));

      _drawCloudPuff(canvas, Offset(x, y), puffW, color.withValues(alpha: opacity));
    }
  }

  void _drawCloudPuff(Canvas canvas, Offset center, double width, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final h = width * 0.32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: width, height: h), Radius.circular(h * 0.5)),
      paint,
    );
    canvas.drawCircle(Offset(center.dx - width * 0.22, center.dy - h * 0.15), h * 0.65, paint);
    canvas.drawCircle(Offset(center.dx + width * 0.08, center.dy - h * 0.35), h * 0.85, paint);
    canvas.drawCircle(Offset(center.dx + width * 0.3, center.dy - h * 0.1), h * 0.55, paint);
  }

  // --- Rain: continuous falling streaks, looping seamlessly, wind-slanted.
  // Integer speed (2 or 3 whole falls per t-cycle) instead of a fractional
  // intensity-scaled speed, so it wraps with no jump; intensity still
  // controls streak count/length/opacity instead.
  void _paintRain(Canvas canvas, Size size, {required double intensity}) {
    final random = math.Random(23);
    final count = (18 + intensity * 32).round();
    final speed = intensity >= 0.9 ? 3 : 2;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 + intensity * 0.25)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * (size.width + 40) - 20;
      final phase = random.nextDouble();
      final length = size.height * (0.05 + intensity * 0.04);
      final localT = (t * speed + phase) % 1.0;
      final y = localT * (size.height + length) - length;
      final x = baseX + localT * 14; // gentle wind slant as it falls
      canvas.drawLine(Offset(x, y), Offset(x - 6, y + length), paint);
    }
  }

  // --- Snow: falling flakes that sway side to side. Each flake picks an
  // integer speed (1 or 2 whole falls per t-cycle) instead of a random
  // fractional one, so every flake wraps seamlessly.
  void _paintSnow(Canvas canvas, Size size) {
    final random = math.Random(29);
    const count = 26;
    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * size.width;
      final phase = random.nextDouble();
      final speed = 1 + random.nextInt(2); // 1 or 2
      final radius = 1.2 + random.nextDouble() * 1.8;
      final localT = (t * speed + phase) % 1.0;
      final y = localT * size.height;
      final sway = math.sin((t + phase) * math.pi * 4) * 10;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.5 + 0.3 * math.sin(localT * math.pi));
      canvas.drawCircle(Offset(baseX + sway, y), radius, paint);
    }
  }

  // --- Storm: periodic whole-card lightning flash ---
  void _paintLightningFlash(Canvas canvas, Size size) {
    // Fires roughly every ~4s within the loop, brief and bright.
    const flashWindow = 0.06;
    final windows = [0.15, 0.55];
    for (final w in windows) {
      final localT = (t - w) % 1.0;
      if (localT < 0 || localT > flashWindow) continue;
      final progress = localT / flashWindow;
      final alpha = (1.0 - progress) * 0.35;
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(WeatherAmbiencePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.tCloud != tCloud ||
      oldDelegate.weatherCode != weatherCode ||
      oldDelegate.isDay != isDay;
}

/// Drives a [WeatherAmbiencePainter] with two independent tickers - a fast
/// 8s one for rain/snow/stars/lightning, and a slow 28s one just for cloud
/// drift, so clouds glide at a calmer, more natural pace instead of racing
/// across the card every 8 seconds.
class WeatherAmbienceLayer extends StatefulWidget {
  final int weatherCode;
  final bool isDay;
  const WeatherAmbienceLayer({super.key, required this.weatherCode, required this.isDay});

  @override
  State<WeatherAmbienceLayer> createState() => _WeatherAmbienceLayerState();
}

class _WeatherAmbienceLayerState extends State<WeatherAmbienceLayer> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _cloudController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _cloudController = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _cloudController]),
      builder: (context, _) => CustomPaint(
        painter: WeatherAmbiencePainter(
          t: _controller.value,
          tCloud: _cloudController.value,
          weatherCode: widget.weatherCode,
          isDay: widget.isDay,
        ),
        size: Size.infinite,
      ),
    );
  }
}
