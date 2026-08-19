import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/weather_service.dart';
import '../services/preferences_service.dart';
import '../theme/design_tokens.dart';
import '../utils/greeting_utils.dart';

enum WeatherShapeType { sun, moon, clouds, rain, snow, storm, fog }

WeatherShapeType _shapeFor(int code, bool isDay) {
  if (!isDay) {
    if (code >= 51 && code <= 82) return WeatherShapeType.rain;
    if (code >= 71 && code <= 77) return WeatherShapeType.snow;
    if (code >= 95) return WeatherShapeType.storm;
    if (code >= 45 && code <= 48) return WeatherShapeType.fog;
    if (code >= 1 && code <= 3) return WeatherShapeType.clouds;
    return WeatherShapeType.moon;
  }
  if (code == 0) return WeatherShapeType.sun;
  if (code >= 1 && code <= 3) return WeatherShapeType.clouds;
  if (code >= 45 && code <= 48) return WeatherShapeType.fog;
  if (code >= 51 && code <= 82) return WeatherShapeType.rain;
  if (code >= 71 && code <= 77) return WeatherShapeType.snow;
  if (code >= 95) return WeatherShapeType.storm;
  return WeatherShapeType.clouds;
}

class WeatherIconPainter extends CustomPainter {
  final WeatherShapeType type;
  final double t; // 0.0 to 1.0 looping
  final Color color;

  WeatherIconPainter({required this.type, required this.t, required this.color});

  void _drawCloud(Canvas canvas, Size size, Paint paint, double driftOffset) {
    final cx = size.width / 2 + driftOffset;
    final cy = size.height / 2;
    final w = size.width;

    // Draw the rounded base rect
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w * 0.35, cy, cx + w * 0.35, cy + w * 0.25), 
      Radius.circular(w * 0.125)
    );
    canvas.drawRRect(baseRect, paint);
    
    // Draw overlapping circles for the puffs
    canvas.drawCircle(Offset(cx - w * 0.15, cy + w * 0.05), w * 0.18, paint);
    canvas.drawCircle(Offset(cx + w * 0.1, cy - w * 0.05), w * 0.25, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (type) {
      case WeatherShapeType.sun:
        // Slow breathing pulse
        final pulse = math.sin(t * math.pi * 2);
        canvas.drawCircle(Offset(cx, cy), w * 0.22, paint);
        
        final rayPaint = Paint()
          ..color = color.withValues(alpha: 0.7 + 0.3 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08
          ..strokeCap = StrokeCap.round;
        
        final inner = w * 0.30;
        final outer = w * (0.42 + 0.04 * pulse); // gentle expansion
        
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4);
          canvas.drawLine(
            Offset(cx + math.cos(angle) * inner, cy + math.sin(angle) * inner),
            Offset(cx + math.cos(angle) * outer, cy + math.sin(angle) * outer),
            rayPaint,
          );
        }
        break;

      case WeatherShapeType.moon:
        final pulse = math.sin(t * math.pi * 2);
        paint.color = color.withValues(alpha: 0.85 + 0.15 * pulse);
        
        final moonPath = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset(cx + w * 0.05, cy), radius: w * 0.35)),
          Path()..addOval(Rect.fromCircle(center: Offset(cx - w * 0.1, cy - w * 0.1), radius: w * 0.32))
        );
        canvas.drawPath(moonPath, paint);
        break;

      case WeatherShapeType.clouds:
        final driftOffset = math.sin(t * math.pi * 2) * w * 0.05;
        _drawCloud(canvas, size, paint, driftOffset);
        break;

      case WeatherShapeType.fog:
        final driftOffset = math.sin(t * math.pi * 2) * w * 0.05;
        _drawCloud(canvas, size, paint, driftOffset);
        
        final linePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08
          ..strokeCap = StrokeCap.round;
          
        canvas.drawLine(Offset(cx - w * 0.35 + driftOffset, cy + w * 0.35), Offset(cx + w * 0.35 + driftOffset, cy + w * 0.35), linePaint);
        canvas.drawLine(Offset(cx - w * 0.2 + driftOffset, cy + w * 0.5), Offset(cx + w * 0.2 + driftOffset, cy + w * 0.5), linePaint);
        break;

      case WeatherShapeType.rain:
        _drawCloud(canvas, size, paint, 0); // static cloud
        final linePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.06
          ..strokeCap = StrokeCap.round;
          
        final ys = [(t + 0.0) % 1.0, (t + 0.33) % 1.0, (t + 0.66) % 1.0];
        final xs = [cx - w * 0.2, cx, cx + w * 0.2];
        
        for (int i = 0; i < 3; i++) {
           final yNorm = ys[i];
           final alpha = math.sin(yNorm * math.pi); // fade in and out
           linePaint.color = color.withValues(alpha: alpha);
           final startY = cy + w * 0.15 + yNorm * w * 0.4;
           canvas.drawLine(Offset(xs[i], startY), Offset(xs[i] - w * 0.08, startY + w * 0.15), linePaint);
        }
        break;

      case WeatherShapeType.snow:
        _drawCloud(canvas, size, paint, 0);
        final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
        final ys = [(t + 0.0) % 1.0, (t + 0.4) % 1.0, (t + 0.7) % 1.0];
        final xs = [cx - w * 0.2, cx + w * 0.1, cx - w * 0.05];
        
        for (int i = 0; i < 3; i++) {
           final yNorm = ys[i];
           final alpha = math.sin(yNorm * math.pi);
           dotPaint.color = color.withValues(alpha: alpha);
           final startY = cy + w * 0.15 + yNorm * w * 0.4;
           final wiggle = math.sin(yNorm * math.pi * 2) * w * 0.05;
           canvas.drawCircle(Offset(xs[i] + wiggle, startY), w * 0.05, dotPaint); 
        }
        break;

      case WeatherShapeType.storm:
        _drawCloud(canvas, size, paint, 0);
        final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
        final boltPaint = Paint()
          ..color = color.withValues(alpha: 0.4 + 0.6 * pulse)
          ..style = PaintingStyle.fill;
          
        final path = Path();
        path.moveTo(cx - w * 0.05, cy + w * 0.15);
        path.lineTo(cx + w * 0.15, cy + w * 0.15);
        path.lineTo(cx + w * 0.02, cy + w * 0.4);
        path.lineTo(cx + w * 0.12, cy + w * 0.35);
        path.lineTo(cx - w * 0.1, cy + w * 0.7);
        path.lineTo(cx - w * 0.02, cy + w * 0.4);
        path.lineTo(cx - w * 0.12, cy + w * 0.45);
        path.close();
        canvas.drawPath(path, boltPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(WeatherIconPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.type != type || oldDelegate.color != color;
  }
}

class AnimatedWeatherIcon extends StatefulWidget {
  final int weatherCode;
  final bool isDay;
  final Color color;
  final double size;

  const AnimatedWeatherIcon({
    Key? key,
    required this.weatherCode,
    required this.isDay,
    required this.color,
    this.size = 32.0,
  }) : super(key: key);

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final shape = _shapeFor(widget.weatherCode, widget.isDay);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: WeatherIconPainter(
              type: shape,
              t: reducedMotion ? 0.0 : _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> with WidgetsBindingObserver {
  WeatherData? _weatherData;
  bool _isLoading = true;
  String _userName = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (WeatherService.cachedWeather != null) {
      _weatherData = WeatherService.cachedWeather;
      _isLoading = false;
    }
    _fetchWeather();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getDisplayName();
    if (mounted) setState(() => _userName = name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) setState(() { _weatherData = data; _isLoading = false; });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isDay {
    final h = DateTime.now().hour;
    return h >= 6 && h < 20;
  }

  Color _getBackgroundColor(BuildContext context, int code, bool day) {
    if (Theme.of(context).brightness == Brightness.dark) return Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.05);
    if (!day) return AppTokens.nightBg;
    if (code == 0) return AppTokens.daylightBg;
    if (code >= 1 && code <= 3) return Color.lerp(AppTokens.daylightBg, AppTokens.dawnStart, 0.08)!;
    if (code >= 45 && code <= 48) return Color.lerp(AppTokens.daylightBg, AppTokens.dawnStart, 0.12)!;
    if (code >= 51 && code <= 82) return Color.lerp(AppTokens.daylightBg, AppTokens.nightBg, 0.08)!;
    if (code >= 71 && code <= 77) return AppTokens.daylightBg;
    if (code >= 95) return Color.lerp(AppTokens.daylightBg, AppTokens.nightBg, 0.12)!;
    return AppTokens.daylightBg;
  }

  Color _getTextColor(BuildContext context, Color bgColor) {
    if (Theme.of(context).brightness == Brightness.dark) return Colors.white;
    return bgColor.computeLuminance() > 0.5 ? AppTokens.nightBg : Colors.white;
  }

  Color _getSubtextColor(BuildContext context, Color bgColor) {
    if (Theme.of(context).brightness == Brightness.dark) return Colors.white60;
    return bgColor.computeLuminance() > 0.5 ? AppTokens.nightBg.withValues(alpha: 0.6) : Colors.white60;
  }

  String _greeting() => GreetingUtils.getGreeting();

  @override
  Widget build(BuildContext context) {
    final day = _isDay;
    final bgColor = _weatherData != null ? _getBackgroundColor(context, _weatherData!.weatherCode, day) : (Theme.of(context).brightness == Brightness.dark ? (Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.05)) : (day ? AppTokens.daylightBg : AppTokens.nightBg));
    final textColor = _getTextColor(context, bgColor);
    final subTextColor = _getSubtextColor(context, bgColor);
    
    final border = Theme.of(context).brightness == Brightness.dark 
        ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) 
        : null;

    if (_isLoading && _weatherData == null) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: border,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: textColor.withValues(alpha: 0.3))),
      );
    }

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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: border,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Personalize your mornings", style: AppTokens.display.copyWith(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Use location for:\n✓ weather\n✓ sunrise\n✓ daily conditions", style: AppTokens.body.copyWith(color: subTextColor)),
              const SizedBox(height: 12),
              Text("Tap to allow →", style: AppTokens.body.copyWith(color: AppTokens.signal, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final upcoming = _weatherData!.hourly
        .where((h) => h.time.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .take(5)
        .toList();

    String sunriseStr = "–", sunsetStr = "–";
    if (_weatherData!.daily.isNotEmpty) {
      sunriseStr = DateFormat('h:mm a').format(_weatherData!.daily.first.sunrise);
      sunsetStr  = DateFormat('h:mm a').format(_weatherData!.daily.first.sunset);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: border,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      style: AppTokens.display.copyWith(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(_weatherData!.conditionTitle, style: AppTokens.body.copyWith(color: subTextColor, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedWeatherIcon(
                    weatherCode: _weatherData!.weatherCode,
                    isDay: day,
                    color: textColor.withValues(alpha: 0.85),
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text('${_weatherData!.temperature.floor()}°', style: AppTokens.display.copyWith(color: textColor, fontSize: 26, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                final h = upcoming[i];
                final timeStr = i == 0 ? "Now" : DateFormat('h a').format(h.time);
                return Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(timeStr, style: AppTokens.body.copyWith(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 6),
                      AnimatedWeatherIcon(
                        weatherCode: h.weatherCode,
                        isDay: day,
                        color: subTextColor,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text('${h.temperature.floor()}°', style: AppTokens.body.copyWith(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.wb_twilight_rounded, color: day ? AppTokens.signal : AppTokens.dawnEnd, size: 14),
              const SizedBox(width: 6),
              Text('Rise $sunriseStr', style: AppTokens.body.copyWith(color: subTextColor, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.nights_stay_rounded, color: subTextColor, size: 14),
              const SizedBox(width: 6),
              Text('Set $sunsetStr', style: AppTokens.body.copyWith(color: subTextColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
