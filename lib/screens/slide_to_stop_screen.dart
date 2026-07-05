import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'ringing_screen.dart';
import '../models/mission_settings.dart';
import 'dart:ui';
import '../services/weather_service.dart';
import '../services/preferences_service.dart';
import '../utils/greeting_utils.dart';

class SlideToStopScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const SlideToStopScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<SlideToStopScreen> createState() => _SlideToStopScreenState();
}

class _SlideToStopScreenState extends State<SlideToStopScreen> with SingleTickerProviderStateMixin {
  String _userName = "Grandmaster";
  late AnimationController _bgAnimController;
  WeatherData? _weatherData;
  
  @override
  void initState() {
    super.initState();
    _weatherData = WeatherService.cachedWeather;
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _loadName();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getUserName();
    if (mounted) setState(() => _userName = name);
  }
  
  @override
  void dispose() {
    _timer.cancel();
    _bgAnimController.dispose();
    super.dispose();
  }
  
  late Timer _timer;
  String _currentTime = "";

  List<Color> _getWeatherGradients() {
     if (_weatherData == null) return [Colors.indigo.shade900, Colors.purple.shade900];
     final code = _weatherData!.weatherCode;
     if (code == 0) return [Colors.blue.shade400, Colors.orange.shade300]; // Sunny
     if (code >= 1 && code <= 3) return [Colors.blueGrey.shade400, Colors.grey.shade600]; // Cloud
     if (code >= 51 && code <= 67) return [Colors.blueGrey.shade800, Colors.blue.shade900]; // Rain
     if (code >= 71 && code <= 77) return [Colors.lightBlue.shade200, Colors.grey.shade300]; // Snow
     return [Colors.indigo.shade900, Colors.purple.shade900];
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm').format(DateTime.now());
    });
  }

  void _onSlideComplete() async {
    Haptics.vibrate(HapticsType.heavy);
    
    bool hasMission = true;
    if (widget.alarmSettings.payload != null) {
      try {
        final settings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
        hasMission = settings.mission != 'none';
      } catch (e) {
        // Default to true
      }
    }
    
    if (!mounted) return;
    if (hasMission) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RingingScreen(alarmSettings: widget.alarmSettings),
        ),
      );
    } else {
      await Alarm.stop(widget.alarmSettings.id);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 80),
                  const SizedBox(height: 20),
                  const Text("Alarm Complete ✓", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("Done", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getWeatherGradients(),
                begin: Alignment.topLeft,
                end: Alignment(1.0, _bgAnimController.value * 2 - 1.0),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(GreetingUtils.getGreeting(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_weatherData != null)
                     Text('${_weatherData!.iconEmoji} ${_weatherData!.conditionTitle} · ${_weatherData!.temperature.floor()}°C', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 40),
                  const Spacer(),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.white.withOpacity(0.5), size: 16),
                const SizedBox(width: 8),
                Text(
                  "Wake up early",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              _currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.w500,
                letterSpacing: -2.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Chess Alarm",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: SlideAction(
                onSubmit: _onSlideComplete,
              ),
            ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SlideAction extends StatefulWidget {
  final VoidCallback onSubmit;

  const SlideAction({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  double _dragPosition = 0.0;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        const double thumbWidth = 60.0;
        const double trackHeight = 60.0;
        final double maxDrag = trackWidth - thumbWidth;

        return Container(
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(trackHeight / 2),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: 1.0 - (_dragPosition / maxDrag).clamp(0.0, 1.0),
                  child: Text(
                    "slide to stop",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_submitted) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_submitted) return;
                    if (_dragPosition > maxDrag * 0.85) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _submitted = true;
                      });
                      widget.onSubmit();
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    width: thumbWidth,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.stop_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
