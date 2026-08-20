import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../features/alarms/application/alarm_controller.dart';
import '../features/alarms/application/wake_session_controller.dart';
import 'ringing_screen.dart';
import 'wake_success_screen.dart';
import '../models/mission_settings.dart';
import '../services/weather_service.dart';
import '../services/alarm_announcement_service.dart';
import '../services/preferences_service.dart';
import '../utils/greeting_utils.dart';
import '../theme/design_tokens.dart';
import '../services/wallpaper_service.dart';
import '../widgets/platform_theme.dart';
import '../widgets/fade_slide_in.dart';

class SlideToStopScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const SlideToStopScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<SlideToStopScreen> createState() => _SlideToStopScreenState();
}

class _SlideToStopScreenState extends State<SlideToStopScreen> with SingleTickerProviderStateMixin {
  String _userName = "";
  late AnimationController _bgAnimController;
  WeatherData? _weatherData;
  MissionSettings? _missionSettings;
  
  @override
  void initState() {
    super.initState();
    _weatherData = WeatherService.cachedWeather;
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    
    if (widget.alarmSettings.payload != null) {
      try {
        _missionSettings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
      } catch (e) {
        // Ignore
      }
    }

    // Guaranteed trigger point on this (legacy/Android) ring path: the
    // `alarm` plugin already runs real Dart code the instant it rings, no
    // user interaction required, so this is the earliest reliable moment
    // to speak — unlike AlarmKit, which needs the process alive already.
    AlarmAnnouncementService.maybeSpeak(
      alarmId: widget.alarmSettings.id,
      announcementMode: _missionSettings?.announcementMode ?? 'off',
      announceDay: _missionSettings?.announceDay ?? true,
      announceDate: _missionSettings?.announceDate ?? true,
      announceTime: _missionSettings?.announceTime ?? true,
      announceWeather: _missionSettings?.announceWeather ?? true,
    );

    _loadName();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getDisplayName();
    if (mounted) setState(() => _userName = name);
  }
  
  @override
  void dispose() {
    _timer.cancel();
    _bgAnimController.dispose();
    AlarmAnnouncementService.stop();
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

  void _handleSnooze() async {
    // No wake session exists yet at this point in the flow (one only
    // starts once the user actually slides to stop), so this is a direct,
    // simple reschedule - nothing to tear down.
    final snoozed = await AlarmController.instance.snoozeAlarm(widget.alarmSettings.id);
    if (!mounted) return;
    if (snoozed) {
      Haptics.vibrate(HapticsType.medium);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No snoozes left for this alarm.')),
      );
    }
  }

  void _onSlideComplete() async {
    Haptics.vibrate(HapticsType.heavy);
    
    bool isWakeRoutine = true;
    bool hasMission = false;
    if (widget.alarmSettings.payload != null) {
      try {
        final settings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
        isWakeRoutine = settings.type == 'wakeRoutine';
        hasMission = settings.mission != 'none';
      } catch (e) {
        // Default to true
      }
    }
    
    if (!mounted) return;
    if (isWakeRoutine || hasMission) {
      // RingingScreen's completion paths (_handleSuccess / _emergencyEscape)
      // resolve through WakeSessionController.completeSession() /
      // emergencyEscape(), both of which are no-ops unless a session is
      // already active for this alarm. On iOS that session is started by
      // the AlarmKit event pipeline before RingingScreen ever appears; on
      // this legacy/Android path nothing else starts one, so without this
      // call, completing a mission here would silently never invoke
      // AlarmController.completeAlarm() — recurring alarms would never
      // reschedule, and one-shot alarms wouldn't be cleanly disabled.
      // startAudio is false because the `alarm` plugin already owns
      // playback on this path; WakeAudioSessionController must not also
      // start audio and double up.
      await WakeSessionController.instance.startSession(widget.alarmSettings.id, startAudio: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RingingScreen(alarmSettings: widget.alarmSettings),
        ),
      );
    } else {
      await AlarmController.instance.completeAlarm(widget.alarmSettings.id);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WakeSuccessScreen(
            message: _userName.isEmpty ? 'Wake up!' : 'Wake up, $_userName!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: PlatformScaffold(
        forceDarkWallpaperScrim: true,
        body: AnimatedBuilder(
          animation: _bgAnimController,
          builder: (context, child) {
            // This used to be a fully opaque gradient, which — like the
            // ringing screen's own sunrise gradient — silently made a
            // custom wallpaper invisible on this screen (the legacy/
            // Android "slide to stop" lock-screen UI) even once
            // PlatformScaffold was wired in to render one underneath.
            final hasWallpaper = WallpaperService().wallpaperPath != null;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasWallpaper
                      ? _getWeatherGradients().map((c) => c.withValues(alpha: 0.45)).toList()
                      : _getWeatherGradients(),
                  begin: Alignment.topLeft,
                  end: Alignment(1.0, _bgAnimController.value * 2 - 1.0),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    FadeSlideIn(child: Column(children: [
                      Text('${GreetingUtils.getGreeting()}, $_userName', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_weatherData != null)
                         Text('${_weatherData!.iconEmoji} ${_weatherData!.conditionTitle} · ${_weatherData!.temperature.floor()}°C', style: const TextStyle(color: Colors.white54, fontSize: 18)),
                    ])),
                  const SizedBox(height: 40),
                  const Spacer(),

              const SizedBox(height: 20),
              FadeSlideIn(delay: const Duration(milliseconds: 100), child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _missionSettings?.mission != 'none' ? Icons.psychology : Icons.alarm,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _missionSettings?.label?.isNotEmpty == true
                        ? _missionSettings!.label!
                        : "Alarm Ringing",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 40),
            FadeSlideIn(delay: const Duration(milliseconds: 180), child: Column(children: [
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
                "Wakle",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ])),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _handleSnooze,
                  icon: const Icon(Icons.snooze, color: Colors.white),
                  label: Text(
                    'Snooze (${AlarmController.instance.remainingSnoozes(widget.alarmSettings.id)} left)',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FadeSlideIn(delay: const Duration(milliseconds: 260), child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: SlideAction(
                onSubmit: _onSlideComplete,
              ),
            )),
                ],
              ),
            ),
          );
        },
      ),
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

class _SlideActionState extends State<SlideAction> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _submitted = false;
  bool _pastThreshold = false;

  late final AnimationController _snapBackController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _snapBackController.addListener(() {
      setState(() {
        _dragPosition = _dragPosition * (1 - _snapBackController.value);
      });
    });
    // A slow, gentle pulse on the track's glow so the eye is drawn to the
    // primary action even before the user starts dragging - the same
    // breathing-attention pattern used for empty states elsewhere.
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _snapBack() {
    _snapBackController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _dragPosition = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        const double thumbWidth = 60.0;
        const double trackHeight = 60.0;
        final double maxDrag = trackWidth - thumbWidth;

        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(trackHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTokens.signal.withValues(alpha: 0.08 + (0.10 * _glowController.value)),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: 1.0 - (_dragPosition / maxDrag).clamp(0.0, 1.0),
                  child: Text(
                    "slide to stop",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
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

                      final crossedThreshold = _dragPosition > maxDrag * 0.85;
                      if (crossedThreshold && !_pastThreshold) {
                        Haptics.vibrate(HapticsType.light);
                      }
                      _pastThreshold = crossedThreshold;
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
                      _pastThreshold = false;
                      _snapBack();
                    }
                  },
                  child: AnimatedScale(
                    scale: _pastThreshold ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: thumbWidth,
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _pastThreshold ? 0.32 : 0.2),
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.stop_rounded, color: Colors.white),
                      ),
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
