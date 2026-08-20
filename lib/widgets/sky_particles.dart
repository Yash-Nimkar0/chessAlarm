import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A field of drifting, twinkling motes — stars at night, soft light at
/// day — plus, when [vivid] is on, an occasional shooting star streaking
/// across at night. So a gradient "sky" hero reads as genuinely alive
/// instead of a flat rectangle. Each mote has its own phase offset so they
/// twinkle independently instead of pulsing in lockstep. Shared by the Home
/// and Morning screens' hero cards so both feel like the same living sky —
/// [vivid] is reserved for the bigger, more expressive Morning hero, since
/// the compact Home glance card shouldn't be this busy.
class SkyParticlesPainter extends CustomPainter {
  final double t;
  final bool night;
  final bool vivid;

  SkyParticlesPainter({required this.t, required this.night, this.vivid = false});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final count = night ? (vivid ? 46 : 28) : (vivid ? 20 : 14);
    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final phase = random.nextDouble();
      final radius = night ? (0.6 + random.nextDouble() * 1.4) : (1.5 + random.nextDouble() * 2.5);

      final twinkle = (math.sin((t + phase) * math.pi * 2) + 1) / 2;
      final drift = night ? 0.0 : math.sin((t + phase) * math.pi * 2) * 6;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: (night ? 0.15 : 0.08) + twinkle * (night ? 0.55 : 0.18))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(baseX + drift, baseY), radius, paint);
    }

    if (vivid && night) {
      _paintShootingStars(canvas, size);
    }
  }

  void _paintShootingStars(Canvas canvas, Size size) {
    // Two independent shooting stars, each firing once per ~8s loop at its
    // own offset window, streaking diagonally with a fading trail.
    for (final seed in [11, 41]) {
      final random = math.Random(seed);
      final startDelay = random.nextDouble() * 0.6; // when in the loop it fires
      const flightDuration = 0.18; // fraction of the loop the streak takes
      final localT = (t - startDelay) % 1.0;
      if (localT < 0 || localT > flightDuration) continue;

      final progress = localT / flightDuration;
      final startX = size.width * (0.15 + random.nextDouble() * 0.5);
      final startY = size.height * (0.05 + random.nextDouble() * 0.2);
      const angle = 0.55; // radians, down-right streak
      final travel = size.width * 0.5;

      final headX = startX + math.cos(angle) * travel * progress;
      final headY = startY + math.sin(angle) * travel * progress;
      final tailX = headX - math.cos(angle) * travel * 0.25;
      final tailY = headY - math.sin(angle) * travel * 0.25;

      final fade = math.sin(progress * math.pi); // fades in then out
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

  @override
  bool shouldRepaint(SkyParticlesPainter oldDelegate) => oldDelegate.t != t;
}

/// Drives a [SkyParticlesPainter] with its own ticker so callers don't need
/// to manage an AnimationController themselves.
class SkyParticlesLayer extends StatefulWidget {
  final bool night;
  final bool vivid;
  const SkyParticlesLayer({super.key, required this.night, this.vivid = false});

  @override
  State<SkyParticlesLayer> createState() => _SkyParticlesLayerState();
}

class _SkyParticlesLayerState extends State<SkyParticlesLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
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
      builder: (context, _) => CustomPaint(
        painter: SkyParticlesPainter(t: _controller.value, night: widget.night, vivid: widget.vivid),
        size: Size.infinite,
      ),
    );
  }
}
