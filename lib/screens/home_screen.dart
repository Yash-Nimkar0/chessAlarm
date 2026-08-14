import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/mission_settings.dart';
import 'edit_alarm_screen.dart';
import 'quick_alarm_screen.dart';

import '../widgets/platform_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<AlarmSettings> alarms = [];
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
    bool granted = true;
    if (Platform.isIOS) {
      granted = await Permission.notification.isGranted;
    } else if (Platform.isAndroid) {
      granted = await Permission.notification.isGranted && 
                await Permission.systemAlertWindow.isGranted;
    }
    if (mounted && granted != _permissionsGranted) {
      setState(() {
        _permissionsGranted = granted;
      });
    }
  }

  void loadAlarms() async {
    final fetchedAlarms = await Alarm.getAlarms();
    fetchedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) {
      setState(() {
        alarms = fetchedAlarms;
        _updateNextAlarmText();
      });
    }
  }

  void _updateNextAlarmText() {
    if (alarms.isEmpty) {
      if (_timeUntilNextAlarm != "") {
        setState(() => _timeUntilNextAlarm = "");
      }
      return;
    }
    
    final now = DateTime.now();
    AlarmSettings? nextAlarm;
    for (var a in alarms) {
      if (a.dateTime.isAfter(now)) {
        nextAlarm = a;
        break;
      }
    }
    
    nextAlarm ??= alarms.first;

    final diff = nextAlarm.dateTime.difference(now);
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
    } else {
      text = "Alarm ringing soon...";
    }
    
    if (_timeUntilNextAlarm != text) {
      setState(() => _timeUntilNextAlarm = text);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void navigateToAlarmScreen(AlarmSettings? settings) async {
    if (settings == null) {
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
                leading: const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 32),
                title: Text('🌅 Wake Routine', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Sleep better.\nWake with a challenge.\nTrack your progress.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, true);
                },
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm, color: Colors.blueAccent, size: 32),
                title: Text('⏰ Alarm', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Standard alarm for daily wake ups.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, false);
                },
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer, color: Colors.tealAccent, size: 32),
                title: Text('⏱️ Quick Alarm', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
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
      bool isWake = false;
      if (settings.payload != null) {
         try {
            final Map<String, dynamic> data = jsonDecode(settings.payload!);
            isWake = data['type'] == 'wakeRoutine';
         } catch(e) {}
      }
      _openEditScreen(settings, isWake);
    }
  }

  void _openEditScreen(AlarmSettings? settings, bool isWakeRoutine) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlarmScreen(alarmSettings: settings, isWakeRoutine: isWakeRoutine),
      ),
    );

    if (res != null) {
      loadAlarms();
    }
  }
  bool _isLocked(AlarmSettings alarm) {
    if (alarm.payload != null) {
      final missionSettings = MissionSettings.fromJsonString(alarm.payload!);
      if (!missionSettings.smartLock) return false;
    }
    final diff = alarm.dateTime.difference(DateTime.now());
    return diff.inMinutes < 2 && alarm.dateTime.isAfter(DateTime.now());
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
                onTap: () => openAppSettings(),
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
                        "⚠️ Permissions disabled. Alarms may not ring. Tap to fix.",
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
                    child: Text(
                      'MY ALARMS', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
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
                    style: TextStyle(
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: alarms.length,
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        final locked = _isLocked(alarm);
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
                          child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('h:mm a').format(alarm.dateTime),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: locked ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('EEEE, MMM d').format(alarm.dateTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: locked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.primary,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (locked)
                                    Icon(Icons.lock_rounded, color: colorScheme.error, size: 28)
                                  else
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, color: colorScheme.onSurfaceVariant, size: 28),
                                      onPressed: () async {
                                        await Alarm.stop(alarm.id);
                                        loadAlarms();
                                      },
                                    ),
                                ],
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
