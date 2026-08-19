import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
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
import '../theme/design_tokens.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/platform_theme.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
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

  Widget _buildMockSharedWakeCard() {
    // Explicit amber tones rather than colorScheme.primaryContainer/primary
    // — those correctly follow Material's own conventions, but this app's
    // light theme deliberately seeds primary from a contrast-safe indigo
    // (see main.dart), not the brand's actual amber. Every other highlight
    // surface in the app (buttons, FAB, alarm toggles) is explicitly
    // amber, so this card following the generic Material role instead
    // stood out as an unrelated purple card in light mode.
    final onDark = AppTokens.nightBg;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.signal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: onDark.withValues(alpha: 0.15),
            child: Icon(Icons.people, color: onDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wake Together • 7:00 AM', style: TextStyle(fontWeight: FontWeight.bold, color: onDark)),
                Text('Alex is sleeping', style: TextStyle(color: onDark.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Switch(
            value: true,
            onChanged: (val) {},
            activeColor: onDark,
            activeTrackColor: onDark.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode B: Wakely Firing in 3s...')));
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
                          alarmId: savedAlarm.id,
                          state: AlarmNativeState.firing,
                          audioOwnership: AudioOwnership.wakely,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    child: const Text('Mode B (Wakely Firing)'),
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
              GestureDetector(
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onLongPress: kDebugMode ? _showDeveloperHarness : null,
                      child: Text(
                        'Alarms', 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),



            // Next Alarm Banner
            if (_timeUntilNextAlarm.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
                child: PlatformCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    _timeUntilNextAlarm,
                    style: AppTokens.display.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              )
            else if (alarms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
                child: PlatformCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    "All alarms are currently turned off.",
                    style: AppTokens.display.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            
            // Expanded List View
            Expanded(
              child: alarms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alarm_off_rounded, size: 80, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                          const SizedBox(height: 16),
                          Text(
                            'Set your first wake-up challenge.',
                            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // Extra bottom padding clears the extended FAB — it
                      // was 8px, which let the FAB permanently sit on top
                      // of the last card's toggle/delete controls with no
                      // way to scroll past it and reach them.
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 96.0),
                      itemCount: alarms.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return FadeSlideIn(child: _buildMockSharedWakeCard());
                        final alarmIndex = index - 1;
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
                          child: PlatformCard(
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
                          child: Opacity(
                            opacity: (!alarm.enabled && !locked) ? 0.5 : 1.0,
                            child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('h:mm a').format(alarm.time),
                                          style: AppTokens.display.copyWith(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: locked ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
                                            letterSpacing: 1.5,
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
                                            Icon(Icons.music_note, size: 14, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                            const SizedBox(width: 4),
                                            Text(
                                              SoundRepository.instance.getSoundById(alarm.soundId)?.name ?? 'Unknown',
                                              style: TextStyle(fontSize: 12, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.psychology, size: 14, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                            const SizedBox(width: 4),
                                            Text(
                                              alarm.mission.type.displayName,
                                              style: TextStyle(fontSize: 12, color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (locked)
                                    Icon(Icons.lock_rounded, color: colorScheme.error, size: 28)
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: alarm.enabled,
                                          onChanged: (val) async {
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
