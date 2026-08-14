import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/preferences_service.dart';
import '../theme/design_tokens.dart';
import 'dart:ui';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  WeatherData? _weatherData;
  bool _isLoading = true;
  String _userName = "";
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgAnimController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bgAnimController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _bgAnimController.repeat(reverse: true);
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgAnimController.dispose();
    super.dispose();
  }

  /// Gradient driven by BOTH isDay AND weatherCode.
  /// This fixes the previous bug where clear night == sunny blue gradient.
  List<Color> _getWeatherGradients() {
    if (_weatherData == null) {
      return [AppTokens.nightBg, const Color(0xFF1E1340)];
    }

    final code = _weatherData!.weatherCode;
    final isDay = _weatherData!.isDay;

    if (!isDay) {
      if (code >= 51 && code <= 82) {
        return [const Color(0xFF0D1B2A), const Color(0xFF1B2B44)]; // rainy night
      }
      if (code >= 95) {
        return [const Color(0xFF080E17), const Color(0xFF0F1C2E)]; // stormy night
      }
      return [AppTokens.nightBg, const Color(0xFF1E1340)]; // clear / cloudy night
    }

    // Day branch
    if (code == 0) return [AppTokens.dawnEnd, AppTokens.signal]; // clear day
    if (code >= 1 && code <= 3) {
      return [const Color(0xFF6E7F8D), const Color(0xFF9EAAB5)]; // cloudy day
    }
    if (code >= 45 && code <= 48) {
      return [const Color(0xFF8D9199), const Color(0xFFB0B7BF)]; // foggy day
    }
    if (code >= 51 && code <= 82) {
      return [const Color(0xFF2E4A6B), const Color(0xFF4A6E94)]; // rainy day
    }
    if (code >= 71 && code <= 77) {
      return [const Color(0xFFB8D0E8), const Color(0xFFD9E8F5)]; // snowy day
    }
    if (code >= 95) {
      return [const Color(0xFF1C2B3A), const Color(0xFF2E3E50)]; // stormy day
    }

    return [AppTokens.dawnStart, AppTokens.dawnEnd];
  }

  /// Single Material icon for each WMO weather code + isDay.
  /// No emoji — keeps the icon language consistent with the rest of the app.
  ({IconData icon, Color color}) _getWeatherIcon(int code, bool isDay) {
    if (code == 0) {
      return isDay
          ? (icon: Icons.wb_sunny_rounded, color: Colors.amberAccent)
          : (icon: Icons.nightlight_round, color: Colors.white70);
    }
    if (code >= 1 && code <= 3) {
      return isDay
          ? (icon: Icons.cloud_queue_rounded, color: Colors.white70)
          : (icon: Icons.cloud_rounded, color: Colors.white54);
    }
    if (code >= 45 && code <= 48) return (icon: Icons.foggy, color: Colors.white54);
    if (code >= 51 && code <= 82) {
      return (icon: Icons.grain_rounded, color: Colors.lightBlueAccent);
    }
    if (code >= 71 && code <= 77) {
      return (icon: Icons.ac_unit_rounded, color: Colors.lightBlue.shade100);
    }
    if (code >= 95) {
      return (icon: Icons.thunderstorm_rounded, color: Colors.amberAccent);
    }
    return (icon: Icons.wb_cloudy_rounded, color: Colors.white70);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    // Loading skeleton
    if (_isLoading && _weatherData == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTokens.nightBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
        ),
      );
    }

    // Permission / no-data prompt
    if (_weatherData == null) {
      return GestureDetector(
        onTap: () async {
          final permission = await Geolocator.requestPermission();
          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            setState(() => _isLoading = true);
            _fetchWeather();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTokens.nightBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personalize your mornings",
                style: AppTokens.display.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Use location for:\n✓ weather\n✓ sunrise\n✓ daily conditions",
                style: AppTokens.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                "Tap to allow →",
                style: AppTokens.body.copyWith(
                  color: AppTokens.signal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Hourly forecast — next 6 slots
    final List<HourlyForecast> upcoming = _weatherData!.hourly
        .where((h) => h.time.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .take(6)
        .toList();

    String sunriseStr = "–";
    String sunsetStr = "–";
    if (_weatherData!.daily.isNotEmpty) {
      sunriseStr = DateFormat('h:mm a').format(_weatherData!.daily.first.sunrise);
      sunsetStr = DateFormat('h:mm a').format(_weatherData!.daily.first.sunset);
    }

    final gradients = _getWeatherGradients();
    final mainIcon = _getWeatherIcon(_weatherData!.weatherCode, _weatherData!.isDay);

    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: gradients,
              begin: Alignment.topLeft,
              end: Alignment(1.0, _bgAnimController.value * 2 - 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: gradients.last.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: greeting / condition label / temp + icon ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName.isEmpty
                                    ? '${_greeting()}!'
                                    : '${_greeting()}, $_userName',
                                style: AppTokens.display.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _weatherData!.conditionTitle,
                                style: AppTokens.body
                                    .copyWith(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(mainIcon.icon, color: mainIcon.color, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              '${_weatherData!.temperature.floor()}°',
                              style: AppTokens.display.copyWith(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(color: Colors.white24, height: 1),
                    ),

                    // ── Hourly strip — Material icons, no emoji ──
                    SizedBox(
                      height: 66,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: upcoming.length,
                        itemBuilder: (context, i) {
                          final h = upcoming[i];
                          final timeStr =
                              i == 0 ? "Now" : DateFormat('h a').format(h.time);
                          final hIcon =
                              _getWeatherIcon(h.weatherCode, _weatherData!.isDay);

                          return Padding(
                            padding: const EdgeInsets.only(right: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  timeStr,
                                  style: AppTokens.body.copyWith(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(hIcon.icon, color: hIcon.color, size: 16),
                                const SizedBox(height: 2),
                                Text(
                                  '${h.temperature.floor()}°',
                                  style: AppTokens.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (h.precipitationProbability > 0)
                                  Text(
                                    '${h.precipitationProbability}%',
                                    style: AppTokens.body.copyWith(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(color: Colors.white24, height: 1),
                    ),

                    // ── Sunrise / Sunset — single icon language ──
                    Row(
                      children: [
                        Icon(Icons.wb_twilight_rounded,
                            color: AppTokens.dawnEnd, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Rise $sunriseStr',
                          style:
                              AppTokens.body.copyWith(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(width: 20),
                        Icon(Icons.nights_stay_rounded,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Set $sunsetStr',
                          style:
                              AppTokens.body.copyWith(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
