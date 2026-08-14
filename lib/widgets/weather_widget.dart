import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../services/weather_service.dart';
import '../services/preferences_service.dart';
import '../theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────
// Particle data — generated once at class-load time with fixed seeds
// so positions are deterministic across frames.
// ─────────────────────────────────────────────────────────────────

typedef _P = ({double x, double y0, double spd, double sz, double ph});

List<_P> _genParticles(int n, {required int seed, double yRange = 1.0}) {
  final rng = math.Random(seed);
  return List.generate(n, (_) => (
    x:   rng.nextDouble(),
    y0:  rng.nextDouble() * yRange,
    spd: 0.3 + rng.nextDouble() * 0.8,
    sz:  1.0 + rng.nextDouble() * 3.5,
    ph:  rng.nextDouble() * math.pi * 2,
  ));
}

final _rainParts  = _genParticles(30, seed: 42);
final _snowParts  = _genParticles(22, seed: 17, yRange: 0.95);
final _starParts  = _genParticles(18, seed: 99, yRange: 0.65);
final _cloudParts = _genParticles( 5, seed: 55, yRange: 0.7);

// ─────────────────────────────────────────────────────────────────
// Effect enum + selector
// ─────────────────────────────────────────────────────────────────

enum _Effect { none, sun, rain, snow, storm, stars, clouds }

_Effect _effectFor(int code, bool isDay) {
  if (!isDay) {
    if (code >= 51 && code <= 82) return _Effect.rain;
    if (code >= 71 && code <= 77) return _Effect.snow;
    if (code >= 95) return _Effect.storm;
    if (code >= 1 && code <= 3)  return _Effect.clouds;
    return _Effect.stars;
  }
  if (code == 0) return _Effect.sun;
  if (code >= 1  && code <= 3)  return _Effect.clouds;
  if (code >= 71 && code <= 77) return _Effect.snow;
  if (code >= 95) return _Effect.storm;
  if (code >= 51 && code <= 82) return _Effect.rain;
  return _Effect.none;
}

// ─────────────────────────────────────────────────────────────────
// CustomPainter — all weather animations live here
// ─────────────────────────────────────────────────────────────────

class _WeatherPainter extends CustomPainter {
  final _Effect effect;
  final double t;   // particle loop 0→1
  final double bgT; // slow background loop 0→1

  const _WeatherPainter({
    required this.effect,
    required this.t,
    required this.bgT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case _Effect.sun:    _paintSun(canvas, size);
      case _Effect.rain:   _paintRain(canvas, size, diagonal: false);
      case _Effect.storm:  {
        _paintRain(canvas, size, diagonal: true);
        _paintLightning(canvas, size);
      }
      case _Effect.snow:   _paintSnow(canvas, size);
      case _Effect.stars:  _paintStars(canvas, size);
      case _Effect.clouds: _paintClouds(canvas, size);
      case _Effect.none:   break;
    }
  }

  void _paintSun(Canvas canvas, Size size) {
    // Soft pulsing radial glow from the top-right corner
    final cx = size.width  * 0.82;
    final cy = size.height * -0.08;
    final center = Offset(cx, cy);
    final pulse = 0.18 + 0.07 * math.sin(bgT * math.pi * 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTokens.signal.withValues(alpha: pulse),
          AppTokens.dawnEnd.withValues(alpha: pulse * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.78));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // 8 slowly rotating light rays
    final rotation = bgT * math.pi * 0.3;
    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + rotation;
      final inner = size.width * 0.10;
      final outer = inner + size.width * (0.20 + 0.05 * math.sin(bgT * math.pi * 4 + i));
      final alpha = 0.06 + 0.03 * math.sin(bgT * math.pi * 2 + i * 0.8);
      rayPaint
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * inner, cy + math.sin(angle) * inner),
        Offset(cx + math.cos(angle) * outer, cy + math.sin(angle) * outer),
        rayPaint,
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, {required bool diagonal}) {
    const dropH = 9.0;
    final tilt  = diagonal ? 0.22 : 0.0; // radians
    final dx = math.sin(tilt) * dropH;
    final dy = math.cos(tilt) * dropH;

    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final p in _rainParts) {
      final yNorm = (p.y0 + t * p.spd) % 1.0;
      final x = p.x * size.width;
      final y = yNorm * size.height;
      final alpha = 0.20 + 0.12 * math.sin(t * math.pi * 2 + p.ph);
      paint.color = Colors.lightBlue.withValues(alpha: diagonal ? alpha + 0.12 : alpha);
      canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), paint);
    }
  }

  void _paintLightning(Canvas canvas, Size size) {
    final flash = math.sin(t * math.pi * 11);
    if (flash > 0.96) {
      final intensity = ((flash - 0.96) / 0.04).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: intensity * 0.13),
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _snowParts) {
      final yNorm = (p.y0 + t * p.spd * 0.35) % 1.0;
      final xDrift = p.x + math.sin(t * math.pi * 2 + p.ph) * 0.035;
      final alpha = 0.40 + 0.35 * math.sin(t * math.pi * 2 + p.ph);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(xDrift * size.width, yNorm * size.height),
        p.sz * 0.65,
        paint,
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _starParts) {
      final alpha = 0.20 + 0.50 * ((math.sin(t * math.pi * 2 + p.ph) + 1) / 2);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.x * size.width, p.y0 * size.height), 1.5, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    // Soft ellipses drifting slowly left-to-right at different y-levels.
    // Uses bgT (10s loop) for very slow movement.
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _cloudParts.length; i++) {
      final p = _cloudParts[i];
      // Each cloud drifts across the width over ~1 full bgT cycle at its own speed.
      final xNorm = (p.x + bgT * (0.08 + p.spd * 0.04)) % 1.2 - 0.1;
      final y = p.y0 * size.height;
      final w = size.width * (0.25 + p.sz * 0.06);
      final h = w * 0.45;
      final alpha = 0.07 + 0.05 * math.sin(bgT * math.pi * 2 + p.ph);
      paint.color = Colors.white.withValues(alpha: alpha);

      // Draw a simple cloud: one large ellipse + two smaller overlapping ones.
      final cx = xNorm * size.width;
      final rect = Rect.fromCenter(center: Offset(cx, y), width: w, height: h);
      canvas.drawOval(rect, paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.28, y - h * 0.3), width: w * 0.55, height: h * 0.7), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + w * 0.22, y - h * 0.2), width: w * 0.48, height: h * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.t != t || old.bgT != bgT || old.effect != effect;
}

// ─────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  WeatherData? _weatherData;
  bool _isLoading = true;
  String _userName = "";

  // Two controllers: slow for gradient/sun, fast loop for particles
  late AnimationController _bgController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    if (WeatherService.cachedWeather != null) {
      _weatherData = WeatherService.cachedWeather;
      _isLoading = false;
    }
    _fetchWeather();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _bgController.stop();
      _particleController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _bgController.repeat(reverse: true);
      _particleController.repeat();
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) setState(() { _weatherData = data; _isLoading = false; });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// Use device clock as ground truth so the gradient is ALWAYS
  /// correct regardless of what the API's isDay field returns.
  bool get _isDay {
    final h = DateTime.now().hour;
    return h >= 6 && h < 20;
  }

  List<Color> _gradients() {
    final code = _weatherData?.weatherCode ?? 0;
    final day = _isDay;

    // ── Night branch — anchored to nightBg/dawnStart family ───────
    if (!day) {
      // Cloudy night: slightly lifted indigo
      if (code >= 1  && code <= 3)  return [AppTokens.nightBg, const Color(0xFF1A1640)];
      // Rainy night: deep indigo, hint of violet-blue
      if (code >= 51 && code <= 82) return [const Color(0xFF080D20), const Color(0xFF130E30)];
      // Stormy night: near-black indigo
      if (code >= 95)               return [const Color(0xFF05060F), const Color(0xFF0D0A1E)];
      // Clear / foggy night: stock nightBg with a violet whisper
      return [AppTokens.nightBg, const Color(0xFF1E1340)];
    }

    // ── Day branch — routed through the warm palette ──────────────
    // Clear day: sunrise amber-gold
    if (code == 0)                  return [AppTokens.dawnEnd, AppTokens.signal];
    // Cloudy / overcast day: desaturated plum-grey (dawnStart family, muted)
    if (code >= 1  && code <= 3)    return [const Color(0xFF4A3660), const Color(0xFF7B6680)];
    // Foggy day: hazy lavender between dawnStart and daylightBg
    if (code >= 45 && code <= 48)   return [const Color(0xFF5C4870), const Color(0xFF9E8DA8)];
    // Rainy day: deep indigo with a cool undertone (nightBg territory, not navy)
    if (code >= 51 && code <= 82)   return [const Color(0xFF1A1035), const Color(0xFF362860)];
    // Snowy day: soft warm lavender — daylightBg tinted with dawnStart, not ice-blue
    if (code >= 71 && code <= 77)   return [const Color(0xFFD4C0E4), const Color(0xFFEDE6F5)];
    // Stormy day: full dawnStart drama
    if (code >= 95)                 return [AppTokens.dawnStart, const Color(0xFF1A1035)];
    return [AppTokens.dawnStart, AppTokens.dawnEnd];
  }

  ({IconData icon, Color color}) _icon(int code, bool isDay) {
    if (code == 0)                return isDay
        ? (icon: Icons.wb_sunny_rounded,      color: AppTokens.signal)     // amber from palette
        : (icon: Icons.nightlight_round,      color: Colors.white70);
    if (code >= 1  && code <= 3)  return isDay
        ? (icon: Icons.cloud_queue_rounded,   color: Colors.white70)
        : (icon: Icons.cloud_rounded,         color: Colors.white54);
    if (code >= 45 && code <= 48) return (icon: Icons.foggy,               color: Colors.white54);
    if (code >= 51 && code <= 82) return (icon: Icons.grain_rounded,       color: AppTokens.dawnEnd);  // warm, not lightBlueAccent
    if (code >= 71 && code <= 77) return (icon: Icons.ac_unit_rounded,     color: Colors.white70);
    if (code >= 95)               return (icon: Icons.thunderstorm_rounded, color: AppTokens.signal);  // amber from palette
    return (icon: Icons.wb_cloudy_rounded, color: Colors.white70);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final grads = _gradients();
    final day   = _isDay;

    // ── Loading skeleton ──────────────────────────────────────────
    if (_isLoading && _weatherData == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grads, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)),
      );
    }

    // ── Permission / no-data prompt ───────────────────────────────
    if (_weatherData == null) {
      return GestureDetector(
        onTap: () async {
          final perm = await Geolocator.requestPermission();
          if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
            setState(() => _isLoading = true);
            _fetchWeather();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grads, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Personalize your mornings", style: AppTokens.display.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Use location for:\n✓ weather\n✓ sunrise\n✓ daily conditions", style: AppTokens.body.copyWith(color: Colors.white70)),
              const SizedBox(height: 12),
              Text("Tap to allow →", style: AppTokens.body.copyWith(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // ── Main card ─────────────────────────────────────────────────
    final upcoming = _weatherData!.hourly
        .where((h) => h.time.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .take(6)
        .toList();

    String sunriseStr = "–", sunsetStr = "–";
    if (_weatherData!.daily.isNotEmpty) {
      sunriseStr = DateFormat('h:mm a').format(_weatherData!.daily.first.sunrise);
      sunsetStr  = DateFormat('h:mm a').format(_weatherData!.daily.first.sunset);
    }

    final mainIcon = _icon(_weatherData!.weatherCode, day);
    final effect   = _effectFor(_weatherData!.weatherCode, day);

    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _particleController]),
      builder: (context, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: grads,
              begin: Alignment.topLeft,
              end: Alignment(1.0, _bgController.value * 2 - 1.0),
            ),
            boxShadow: [
              BoxShadow(color: grads.last.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Stack(
                children: [
                  // ── Particle / effect layer (behind text) ──────
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WeatherPainter(
                        effect: effect,
                        t:   _particleController.value,
                        bgT: _bgController.value,
                      ),
                    ),
                  ),

                  // ── Text / content layer ───────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName.isEmpty ? '${_greeting()}!' : '${_greeting()}, $_userName',
                                    style: AppTokens.display.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_weatherData!.conditionTitle, style: AppTokens.body.copyWith(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(mainIcon.icon, color: mainIcon.color, size: 22),
                                const SizedBox(width: 6),
                                Text('${_weatherData!.temperature.floor()}°', style: AppTokens.display.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _weatherData!.contextSentence,
                          style: AppTokens.body.copyWith(color: Colors.white60, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: Colors.white24, height: 1)),

                        // Hourly strip
                        SizedBox(
                          height: 66,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcoming.length,
                            itemBuilder: (context, i) {
                              final h = upcoming[i];
                              final timeStr = i == 0 ? "Now" : DateFormat('h a').format(h.time);
                              final hIcon = _icon(h.weatherCode, day);
                              return Padding(
                                padding: const EdgeInsets.only(right: 20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(timeStr, style: AppTokens.body.copyWith(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Icon(hIcon.icon, color: hIcon.color, size: 16),
                                    const SizedBox(height: 2),
                                    Text('${h.temperature.floor()}°', style: AppTokens.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (h.precipitationProbability > 0)
                                      Text('${h.precipitationProbability}%', style: AppTokens.body.copyWith(color: Colors.lightBlueAccent, fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: Colors.white24, height: 1)),

                        // Sunrise / Sunset
                        Row(
                          children: [
                            Icon(Icons.wb_twilight_rounded, color: AppTokens.dawnEnd, size: 16),
                            const SizedBox(width: 6),
                            Text('Rise $sunriseStr', style: AppTokens.body.copyWith(color: Colors.white60, fontSize: 12)),
                            const SizedBox(width: 20),
                            Icon(Icons.nights_stay_rounded, color: Colors.white54, size: 16),
                            const SizedBox(width: 6),
                            Text('Set $sunsetStr', style: AppTokens.body.copyWith(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
