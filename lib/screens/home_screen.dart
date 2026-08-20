import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/alarms/application/alarm_controller.dart';
import '../features/alarms/application/wake_session_controller.dart';
import '../features/alarms/domain/alarm_capability_service.dart';
import '../features/alarms/domain/alarm_event.dart';
import '../features/alarms/domain/alarm_model.dart';
import '../features/alarms/domain/mission_config.dart';
import '../features/alarms/domain/recurrence.dart';
import 'edit_alarm_screen.dart';
import 'quick_alarm_screen.dart';
import '../features/sounds/data/sound_repository.dart';
import '../services/elo_service.dart';
import '../services/home_widget_service.dart';
import '../services/preferences_service.dart';
import '../theme/design_tokens.dart';
import '../theme/mission_colors.dart';
import '../utils/greeting_utils.dart';
import '../utils/sky_gradient.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/platform_theme.dart';
import '../widgets/sky_particles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<WakelyAlarm> alarms = [];
  StreamSubscription? subscription;
  Timer? _countdownTimer;
  String _timeUntilNextAlarm = "";
  bool _permissionsGranted = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _loadName();
    loadAlarms();
    subscription = Alarm.ringing.listen((_) {
      loadAlarms();
    });
    AlarmController.instance.addListener(loadAlarms);
    
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateNextAlarmText();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final status = await AlarmCapabilityService.check();
    if (mounted && status.isReady != _permissionsGranted) {
      setState(() {
        _permissionsGranted = status.isReady;
      });
    }
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getDisplayName();
    if (mounted) setState(() => _userName = name);
  }

  ScheduledAlarm? _nextScheduled;

  void loadAlarms() async {
    final fetchedAlarms = await AlarmController.instance.getAlarms();
    fetchedAlarms.sort((a, b) => a.time.compareTo(b.time));
    final next = await AlarmController.instance.getNextEnabledAlarm();

    if (mounted) {
      setState(() {
        alarms = fetchedAlarms;
        _nextScheduled = next;
        _updateNextAlarmText();
      });
    }

    final stats = await EloService.getStats();
    unawaited(HomeWidgetService.update(
      nextAlarmTime: next?.nextOccurrence,
      currentStreak: stats['currentStreak'] ?? 0,
    ));
  }

  void _updateNextAlarmText() {
    if (_nextScheduled == null) {
      if (_timeUntilNextAlarm != "") {
        setState(() => _timeUntilNextAlarm = "");
      }
      return;
    }
    
    final now = DateTime.now();
    final diff = _nextScheduled!.nextOccurrence.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    
    String text;
    if (days > 0) {
      text = "Next alarm in ${days}d ${hours}h";
    } else if (hours > 0) {
      text = "Next alarm in ${hours}h ${minutes}m";
    } else if (minutes > 0) {
      text = "Next alarm in ${minutes}m";
    } else if (diff.isNegative) {
      text = "Alarm ringing...";
    } else {
      text = "Alarm ringing soon...";
    }
    
    if (_timeUntilNextAlarm != text) {
      setState(() => _timeUntilNextAlarm = text);
    }
  }

  // The old header was a plain "Alarms" title plus a small separate pill
  // for the countdown - visually flat, and the two pieces of information
  // (title, countdown) never related to each other. This hero merges them
  // into one glanceable moment: a living-sky gradient (same system the
  // Morning screen's weather hero uses, so both screens read as one
  // cohesive app) with the next alarm's actual clock time as the headline,
  // not just a relative countdown.
  Widget _buildHomeHero(ColorScheme colorScheme) {
    final now = DateTime.now();
    final skyColors = SkyGradient.colorsFor(now);
    final isNight = !SkyGradient.isDay(now);
    const heroText = Colors.white;
    final heroSub = Colors.white.withValues(alpha: 0.78);

    final hasNext = _nextScheduled != null && _timeUntilNextAlarm.isNotEmpty;
    final allOff = !hasNext && alarms.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: skyColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: skyColors.last.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: SkyParticlesLayer(night: isNight)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: Colors.white.withValues(alpha: 0.9), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isEmpty ? GreetingUtils.getGreeting() : '${GreetingUtils.getGreeting()}, $_userName',
                          style: AppTokens.body.copyWith(color: heroSub, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (hasNext)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                DateFormat('h:mm a').format(_nextScheduled!.nextOccurrence),
                                style: AppTokens.display.copyWith(color: heroText, fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _timeUntilNextAlarm.replaceFirst('Next alarm ', ''),
                                  style: AppTokens.body.copyWith(color: heroSub, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (allOff)
                          Text('All alarms are off', style: AppTokens.display.copyWith(color: heroText, fontSize: 18, fontWeight: FontWeight.w800))
                        else
                          Text('No alarms yet', style: AppTokens.display.copyWith(color: heroText, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _missionIcon(MissionType type) {
    switch (type) {
      case MissionType.math:
        return Icons.calculate_rounded;
      case MissionType.memory:
        return Icons.psychology_rounded;
      case MissionType.typing:
        return Icons.keyboard_rounded;
      case MissionType.colorTiles:
        return Icons.grid_view_rounded;
      case MissionType.missingSymbol:
        return Icons.extension_rounded;
      case MissionType.shake:
        return Icons.vibration_rounded;
      case MissionType.qr:
        return Icons.qr_code_scanner_rounded;
      case MissionType.steps:
        return Icons.directions_walk_rounded;
      case MissionType.none:
        return Icons.alarm_rounded;
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    AlarmController.instance.removeListener(loadAlarms);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void navigateToAlarmScreen(WakelyAlarm? alarm) async {
    if (alarm == null) {
      // Show type selector
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you setting?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny, color: AppTokens.signal, size: 32),
                title: Text('Wake Routine', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Sleep better.\nWake with a challenge.\nTrack your progress.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, true);
                },
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm, color: AppTokens.signal, size: 32),
                title: Text('Alarm', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Standard alarm for daily wake ups.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, false);
                },
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer, color: AppTokens.signal, size: 32),
                title: Text('Quick Alarm', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Fast timer for naps or reminders.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuickAlarmScreen(),
                    ),
                  );
                  if (res == true) loadAlarms();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      );
    } else {
      _openEditScreen(alarm, alarm.type == AlarmType.wakeRoutine);
    }
  }

  void _openEditScreen(WakelyAlarm? alarm, bool isWakeRoutine) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlarmScreen(alarm: alarm, isWakeRoutine: isWakeRoutine),
      ),
    );

    if (res != null) {
      loadAlarms();
    }
  }

  Future<WakelyAlarm> _createFakeAlarm(
    String soundId, {
    bool fadeIn = false,
    int fadeDuration = 0,
    AlarmType type = AlarmType.standard,
    DateTime? time,
  }) async {
    final fakeAlarm = WakelyAlarm(
      id: 9999,
      time: time ?? DateTime.now(),
      enabled: true,
      type: type,
      soundId: soundId,
      fadeIn: fadeIn,
      fadeDuration: fadeDuration,
      mission: MissionConfig(type: MissionType.typing),
      recurrence: Recurrence.none(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await AlarmController.instance.createAlarm(fakeAlarm);
  }

  void _showDeveloperHarness() {
    showDialog(
      context: context,
      builder: (context) {
        String selectedSound = 'wakely_celestial';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Developer Harness'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trigger a synthetic wake session in 3 seconds.'),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedSound,
                    isExpanded: true,
                    items: SoundRepository.instance.getAvailableSounds().map((s) {
                      return DropdownMenuItem(value: s.id, child: Text(s.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedSound = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode A: Native Firing in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.nativeAlarmKit,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode A (Native Firing)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode B: Wakle Firing in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.wakely,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode B (Wakle Firing)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode C: Handoff Simulation in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        // 1. Initial native firing
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.nativeAlarmKit,
                          timestamp: DateTime.now(),
                        ));
                        
                        // 2. Simulated interaction 2 seconds later
                        Future.delayed(const Duration(seconds: 2), () {
                          WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                            alarmId: savedAlarm.id,
                            state: AlarmNativeState.unknown,
                            interaction: AlarmInteractionType.stop,
                            audioOwnership: AudioOwnership.wakely,
                            timestamp: DateTime.now(),
                          ));
                        });
                      });
                    },
                    child: const Text('Mode C (Production Handoff)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode E: Cold Start Simulation in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        // Simulate AlarmController receiving pending interaction BEFORE UI mounts
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.wakely,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode E (Cold Start/Recovery)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound, fadeIn: true, fadeDuration: 5);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode F: Fade Diagnostic in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.wakely,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode F (Fade ON 5s Diagnostic)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode G: Force-Quit Recovery...')));
                      
                      Future.delayed(const Duration(seconds: 1), () async {
                        // Start session
                        await WakeSessionController.instance.startSession(savedAlarm.id, startAudio: false);
                        // Simulate force-quit by clearing active UI state but leaving SharedPreferences ID
                        await WakeSessionController.instance.stopSession();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('wakely_active_session_alarm_id', savedAlarm.id);
                        
                        // Simulate cold restart
                        Future.delayed(const Duration(seconds: 2), () {
                          // This would normally be called by main.dart or AlarmController.reconcile
                          WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                            alarmId: savedAlarm.id,
                            state: AlarmNativeState.firing,
                            audioOwnership: AudioOwnership.wakely,
                            timestamp: DateTime.now(),
                          ));
                        });
                      });
                    },
                    child: const Text('Mode G (Force-Quit Recovery)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode H: Native Dismissal -> WakeCheck...')));
                      
                      Future.delayed(const Duration(seconds: 2), () {
                        // Simulate user stopping natively
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.stopped,
                          interaction: AlarmInteractionType.stop,
                          audioOwnership: AudioOwnership.nativeAlarmKit,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode H (Native Dismissal)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final savedAlarm = await _createFakeAlarm(selectedSound);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode J: Wake Check Re-alert Simulation...')));
                      
                      Future.delayed(const Duration(seconds: 2), () {
                        // Simulate Wake Check Quick Alarm firing
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: 99999 + savedAlarm.id, // The wake check offset
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.wakely,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode J (Wake Check Simulation)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Real AlarmKit alarm, real mission type, fired ~90s out
                      // via the actual native scheduler — not a synthetic
                      // in-process event. Use this to watch a live AlarmKit
                      // alert appear, then tap its real native Stop button to
                      // verify StopAlarmIntent.perform() natively schedules a
                      // Wake Check re-alert (check getScheduledAlarms/logs).
                      final savedAlarm = await _createFakeAlarm(
                        selectedSound,
                        type: AlarmType.wakeRoutine,
                        time: DateTime.now().add(const Duration(seconds: 90)),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Mode K: REAL AlarmKit alarm #${savedAlarm.id} fires in 90s. Wait for the native alert, then tap its native Stop button.'),
                          duration: const Duration(seconds: 8),
                        ));
                      }
                    },
                    child: const Text('Mode K (Real AlarmKit Wake Check Test)'),
                  ),
                ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            if (!_permissionsGranted)
              AnimatedPressable(
                scaleOnPress: 0.98,
                onTap: () => AlarmCapabilityService.requestAlarmPermissions().then((_) => _checkPermissions()),
                child: Container(
                  width: double.infinity,
                  color: colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "Permissions disabled. Alarms may not ring. Tap to fix.",
                        style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: GestureDetector(
                onLongPress: kDebugMode ? _showDeveloperHarness : null,
                child: _buildHomeHero(colorScheme),
              ),
            ),

            // Expanded List View
            Expanded(
              child: alarms.isEmpty
                  ? Center(
                      child: FadeSlideIn(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            BreathingIcon(
                              icon: Icons.alarm_off_rounded,
                              size: 96,
                              iconSize: 48,
                              color: AppTokens.signal,
                              backgroundColor: AppTokens.signal.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Set your first wake-up challenge.',
                              style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      // Extra bottom padding clears the extended FAB — it
                      // was 8px, which let the FAB permanently sit on top
                      // of the last card's toggle/delete controls with no
                      // way to scroll past it and reach them.
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 96.0),
                      itemCount: alarms.length,
                      itemBuilder: (context, index) {
                        final alarmIndex = index;
                        final alarm = alarms[alarmIndex];
                        final locked = alarm.isLocked;

                        return FadeSlideIn(
                          delay: Duration(milliseconds: (alarmIndex * 40).clamp(0, 320)),
                          child: Dismissible(
                          key: ValueKey('alarm_${alarm.id}'),
                          direction: locked ? DismissDirection.none : DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Alarm?'),
                                content: const Text('Are you sure you want to delete this alarm?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ?? false;
                          },
                          onDismissed: (_) async {
                            await AlarmController.instance.deleteAlarm(alarm.id);
                            loadAlarms();
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 28),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                            ),
                            child: Icon(Icons.delete_outline_rounded, color: colorScheme.onError, size: 28),
                          ),
                          child: Builder(builder: (context) {
                            final isNext = alarm.enabled && !locked && _nextScheduled?.alarm.id == alarm.id;
                            final missionIcon = _missionIcon(alarm.mission.type);
                            final accentColor = locked ? colorScheme.error : missionColor(alarm.mission.type);
                            return PlatformCard(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          onTap: locked ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Alarm locked! Time to wake up soon.'),
                                backgroundColor: colorScheme.error,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } : () => navigateToAlarmScreen(alarm),
                          child: Container(
                            decoration: isNext
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                    border: Border.all(color: AppTokens.signal.withValues(alpha: 0.5), width: 1.5),
                                  )
                                : null,
                            child: Opacity(
                            opacity: (!alarm.enabled && !locked) ? 0.5 : 1.0,
                            child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(top: 2, right: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accentColor.withValues(alpha: locked ? 0.15 : (alarm.enabled ? 0.18 : 0.08)),
                                      ),
                                      child: Icon(locked ? Icons.lock_rounded : missionIcon, color: accentColor, size: 20),
                                    ),
                                    Expanded(
                                      child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isNext) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            margin: const EdgeInsets.only(bottom: 6),
                                            decoration: BoxDecoration(
                                              color: AppTokens.signal.withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                            ),
                                            child: const Text('NEXT UP', style: TextStyle(color: AppTokens.signal, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                          ),
                                        ],
                                        Text(
                                          DateFormat('h:mm a').format(alarm.time),
                                          style: AppTokens.display.copyWith(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: locked ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
                                            letterSpacing: 1.2,
                                            decoration: alarm.enabled ? TextDecoration.none : TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alarm.recurrence.isOneShot
                                            ? DateFormat('EEEE, MMM d').format(alarm.time)
                                            : alarm.recurrence.displayText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.primary,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        if (alarm.label != null && alarm.label!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            alarm.label!,
                                            style: TextStyle(fontSize: 14, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.music_note, size: 13, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                SoundRepository.instance.getSoundById(alarm.soundId)?.name ?? 'Unknown',
                                                style: TextStyle(fontSize: 12, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(missionIcon, size: 13, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              flex: 2,
                                              child: Text(
                                                alarm.mission.type.displayName,
                                                style: TextStyle(fontSize: 12, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ),
                                  if (locked)
                                    const SizedBox(width: 4)
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: alarm.enabled,
                                          activeThumbColor: AppTokens.signal,
                                          activeTrackColor: AppTokens.signal.withValues(alpha: 0.35),
                                          onChanged: (val) async {
                                            Haptics.vibrate(HapticsType.selection);
                                            if (val) {
                                              await AlarmController.instance.enableAlarm(alarm.id);
                                            } else {
                                              await AlarmController.instance.disableAlarm(alarm.id);
                                            }
                                            loadAlarms();
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.onSurfaceVariant, size: 28),
                                          onPressed: () async {
                                            final bool? confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Alarm?'),
                                                content: const Text('Are you sure you want to delete this alarm?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await AlarmController.instance.deleteAlarm(alarm.id);
                                              loadAlarms();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                          );
                          }),
                        ),
                      );
                        },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => navigateToAlarmScreen(null),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text("New Alarm"),
      ),
    );
  }
}
