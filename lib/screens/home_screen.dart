import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/mission_settings.dart';
import 'edit_alarm_screen.dart';
import 'practice_screen.dart';
import 'grandmaster_wake_screen.dart';
import '../services/elo_service.dart';
import '../widgets/platform_theme.dart';
import '../widgets/weather_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<AlarmSettings> alarms = [];
  StreamSubscription? subscription;
  int _userElo = 400;
  List<int> _eloHistory = [];
  Timer? _countdownTimer;
  String _timeUntilNextAlarm = "";
  bool _permissionsGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    loadAlarms();
    _loadElo();
    subscription = Alarm.ringing.listen((_) {
      loadAlarms();
      _loadElo();
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

  void _loadElo() async {
    final elo = await EloService.getElo();
    if (mounted) {
      setState(() {
        _userElo = elo;
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
    
    if (nextAlarm == null) {
      nextAlarm = alarms.first;
    }

    final diff = nextAlarm.dateTime.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    
    String text;
    if (days > 0) {
      text = "Next alarm in $days day${days > 1 ? 's' : ''} and $hours hr${hours != 1 ? 's' : ''}";
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What are you setting?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 32),
                title: const Text('🌅 Wake Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text('Sleep better.\nWake with a challenge.\nTrack your progress.', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, true);
                },
              ),
              const Divider(color: Colors.white12, height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm, color: Colors.blueAccent, size: 32),
                title: const Text('⏰ Quick Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text('Simple alarms for reminders,\nnaps, and daily tasks.', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(null, false);
                },
              ),
              const SizedBox(height: 24),
            ],
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
      _loadElo();
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
                      'CHESS ALARMS', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.military_tech, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$_userElo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Daily Training Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: PlatformCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PracticeScreen()),
                  );
                },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.psychology, color: colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Daily Brain Training",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Practice puzzles to improve your rating without an alarm.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
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
                          Icon(Icons.alarm_off_rounded, size: 80, color: colorScheme.onSurface.withOpacity(0.1)),
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
                                          color: locked ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('EEEE, MMM d').format(alarm.dateTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: locked ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.primary,
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
