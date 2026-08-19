import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../features/alarms/application/wake_session_controller.dart';

import '../models/mission_settings.dart';
import 'missions/math_mission.dart';
import 'missions/memory_mission.dart';
import 'missions/typing_mission.dart';
import 'missions/color_tiles_mission.dart';
import 'missions/missing_symbol_mission.dart';
import 'missions/shake_mission.dart';
import 'missions/qr_mission.dart';
import 'missions/steps_mission.dart';
import 'mission_complete_screen.dart';
import '../theme/design_tokens.dart';
import '../widgets/platform_theme.dart';
import '../widgets/animated_pressable.dart';
import '../services/analytics_service.dart';
import '../services/elo_service.dart';
import '../services/review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sleep_service.dart';
import '../services/wallpaper_service.dart';

class RingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  const RingingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSuccess = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _sunriseController;
  late Animation<Color?> _skyAnimation;

  late MissionSettings _missionSettings;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The mission screen genuinely being shown is the watchdog's "user is
    // actively engaged" signal — pauses the relentless chain's back half
    // (a short live tail always stays armed regardless, so this is safe
    // even if the app is killed the instant after this call).
    WakeSessionController.instance.armMissionWatchdog();
    AnalyticsService.logEvent('alarm_triggered', {'alarm_id': widget.alarmSettings.id});
    _startTime = DateTime.now();
    // A gentle breathing amber glow behind the content — this used to be a
    // ColorTween whose actual value was never read anywhere in build() (it
    // only drove _isFlashingRed, a bool permanently hardcoded to false),
    // so it animated every second for the entire ringing session for no
    // visible effect at all. Repurposed into a real, visible ambient pulse.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    _sunriseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _skyAnimation = TweenSequence<Color?>([
      TweenSequenceItem(weight: 1.0, tween: ColorTween(begin: AppTokens.nightBg, end: AppTokens.dawnStart)),
      TweenSequenceItem(weight: 1.0, tween: ColorTween(begin: AppTokens.dawnStart, end: AppTokens.dawnEnd)),
    ]).animate(_sunriseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _sunriseController.value = 1.0;
      } else {
        _sunriseController.forward();
      }
    });

    if (widget.alarmSettings.payload != null) {
      _missionSettings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
    } else {
      _missionSettings = MissionSettings(type: 'wakeRoutine');
    }

    _isLoading = false;
  }

  void _emergencyEscape() async {
    if (_isProcessing) return;
    
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'emergency_escapes_${DateTime.now().year}_${DateTime.now().month}';
    final currentEscapes = prefs.getInt(monthKey) ?? 0;
    
    if (currentEscapes >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Emergency Escapes remaining this month.')));
      return;
    }
    
    Haptics.vibrate(HapticsType.heavy);
    await prefs.setInt(monthKey, currentEscapes + 1);
    AnalyticsService.logEvent('emergency_escape_used');
    
    if (mounted) {
      setState(() => _isProcessing = true);
    }
    
    await WakeSessionController.instance.emergencyEscape();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      await SleepService.recordWakePerformance(elapsed, true);
      if (_missionSettings.type == 'quickAlarm' || _missionSettings.type == 'alarm') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                    const SizedBox(height: 20),
                    Text('Wake up!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.signal, 
                        foregroundColor: AppTokens.nightBg, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm))
                      ),
                      child: const Text("Done", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MissionCompleteScreen(
              elapsedSeconds: elapsed,
              eloChange: 0,
              isSkip: true,
            ),
          ),
        );
      }
    }
  }



  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = true;
      });
    }
    Haptics.vibrate(HapticsType.heavy);

    await Future.delayed(const Duration(seconds: 2));
    
    await WakeSessionController.instance.completeSession();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      AnalyticsService.logEvent('mission_completed', {
        'solve_time': elapsed,
      });
      await SleepService.recordWakePerformance(elapsed, false);
      await EloService.recordMorningSuccess(solveTimeSeconds: elapsed);
      final stats = await EloService.getStats();
      unawaited(ReviewPromptService.maybeRequestReview(stats['currentStreak'] ?? 0));
      if (_missionSettings.type == 'quickAlarm' || _missionSettings.type == 'alarm') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                    const SizedBox(height: 20),
                    Text('Wake up!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.signal,
                        foregroundColor: AppTokens.nightBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm))
                      ),
                      child: const Text("Done", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MissionCompleteScreen(
              elapsedSeconds: elapsed,
              eloChange: 0,
              isSkip: false,
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The instant the app leaves the foreground while the watchdog is
    // paused, resume immediately — no grace period. Backgrounding or being
    // killed is exactly the scenario the chain exists to survive; the
    // watchdog's pause is only ever safe while we can actually confirm the
    // user is looking at the mission screen.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      WakeSessionController.instance.resumeMissionWatchdogImmediately();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _sunriseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTokens.nightBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTokens.signal),
        ),
      );
    }
    
    Widget content;

    if (_missionSettings.mission == 'math') {
      content = MathMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'memory') {
      content = MemoryMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'typing') {
      content = TypingMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'color_tiles') {
      content = ColorTilesMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'missing_symbol') {
      content = MissingSymbolMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'shake') {
      content = ShakeMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, settings: _missionSettings);
    } else if (_missionSettings.mission == 'qr') {
      content = QRMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, missionData: _missionSettings.missionData ?? {});
    } else if (_missionSettings.mission == 'steps') {
      content = StepsMission(onSuccess: _handleSuccess, onSkip: _emergencyEscape, missionData: _missionSettings.missionData ?? {});
    } else {
      content = Center(
        child: ElevatedButton(
          onPressed: _handleSuccess,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.signal,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
          ),
          child: Text(
            'Stop Alarm',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTokens.nightBg),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _isSuccess,
      child: PlatformScaffold(
        forceDarkWallpaperScrim: true,
        body: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _sunriseController]),
          builder: (context, child) {
            final skyColor = _skyAnimation.value ?? AppTokens.nightBg;
            // This gradient used to be fully opaque, which meant a custom
            // wallpaper (rendered behind it by PlatformScaffold) was
            // completely invisible on this screen despite technically
            // being wired up. Letting it show through here still keeps
            // the sunrise animation, just as a tint over the photo instead
            // of a solid fill, when a wallpaper is actually set.
            final hasWallpaper = WallpaperService().wallpaperPath != null;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (_isSuccess ? Colors.green : skyColor).withValues(alpha: _isSuccess ? 0.4 : (hasWallpaper ? 0.55 : 1.0)),
                    AppTokens.nightBg.withValues(alpha: hasWallpaper ? 0.55 : 1.0),
                  ],
                )
              ),
              // A gentle breathing amber glow — reinforces urgency without
              // the jarring red flash this used to (never actually) do.
              foregroundDecoration: _isSuccess
                  ? null
                  : BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.1,
                        colors: [
                          AppTokens.signal.withValues(alpha: 0.10 + (0.08 * _pulseAnimation.value)),
                          Colors.transparent,
                        ],
                      ),
                    ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      if (_missionSettings.label != null && _missionSettings.label!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Text(
                            _missionSettings.label!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) => WakeSessionController.instance.recordMissionInteraction(),
                          child: content,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: AnimatedPressable(
                          onLongPress: _emergencyEscape,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Long press for Emergency Escape (Limits apply).')),
                              );
                            },
                            icon: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                            label: Text('Emergency Escape', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
