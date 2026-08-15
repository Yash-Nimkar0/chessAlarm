import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'dart:math';

import '../models/mission_settings.dart';
import '../widgets/platform_theme.dart';
import 'edit_alarm_screen.dart';
import 'missions/typing_config_screen.dart';
import 'missions/shake_config_screen.dart';
import 'missions/default_config_screen.dart';
import 'missions/qr_config_screen.dart';
import 'missions/steps_config_screen.dart';
import '../theme/design_tokens.dart';

class QuickAlarmScreen extends StatefulWidget {
  const QuickAlarmScreen({Key? key}) : super(key: key);

  @override
  State<QuickAlarmScreen> createState() => _QuickAlarmScreenState();
}

class _QuickAlarmScreenState extends State<QuickAlarmScreen> {
  DateTime? _targetTime;
  
  late MissionSettings _missionSettings;
  double _volume = 0.8;
  bool _vibrate = true;
  String _assetAudio = 'assets/marimba.mp3';

  @override
  void initState() {
    super.initState();
    _missionSettings = MissionSettings(type: 'quickAlarm', mission: 'none');
  }

  void _addTime(Duration duration) {
    Haptics.vibrate(HapticsType.selection);
    setState(() {
      final now = DateTime.now();
      if (_targetTime == null || _targetTime!.isBefore(now)) {
        _targetTime = now.add(duration);
      } else {
        _targetTime = _targetTime!.add(duration);
      }
    });
  }

  void _resetTime() {
    Haptics.vibrate(HapticsType.heavy);
    setState(() {
      _targetTime = null;
    });
  }

  Future<void> _pickExactTime() async {
    final now = DateTime.now();
    final initialTime = _targetTime != null 
        ? TimeOfDay.fromDateTime(_targetTime!)
        : TimeOfDay.now();
        
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      Haptics.vibrate(HapticsType.selection);
      DateTime selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        selectedDateTime = selectedDateTime.add(const Duration(days: 1));
      }

      setState(() {
        _targetTime = selectedDateTime;
      });
    }
  }

  Future<void> _saveQuickAlarm() async {
    if (_targetTime == null || _targetTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some time first!')),
      );
      return;
    }

    Haptics.vibrate(HapticsType.success);
    
    final alarmSettings = AlarmSettings(
      id: Random().nextInt(10000) + 1,
      dateTime: _targetTime!,
      assetAudioPath: _assetAudio,
      loopAudio: true,
      vibrate: _vibrate,
      volumeSettings: VolumeSettings.fade(
        volume: _volume,
        fadeDuration: const Duration(seconds: 30),
      ),
      notificationSettings: const NotificationSettings(
        title: 'Quick Alarm',
        body: 'Time is up!',
        stopButton: 'Stop',
      ),
      payload: _missionSettings.toJsonString(),
    );

    await Alarm.set(alarmSettings: alarmSettings);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String _getMissionDisplayName(String missionStr) {
    switch (missionStr) {
      case 'math': return 'Math';
      case 'memory': return 'Memory';
      case 'typing': return 'Typing';
      case 'color_tiles': return 'Color Tiles';
      case 'missing_symbol': return 'Missing Symbol';
      case 'shake': return 'Shake';
      case 'qr': return 'QR / Barcode';
      case 'steps': return 'Steps';
      case 'none': return 'None';
      default: return 'Memory';
    }
  }

  void _showMissionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Select Mission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                leading: const Icon(Icons.calculate, color: Colors.blue),
                title: const Text('Math Problem'),
                subtitle: const Text('Solve a math equation to wake up.'),
                trailing: _missionSettings.mission == 'math' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => DefaultMissionConfigScreen(
                      initialSettings: _missionSettings,
                      missionId: 'math',
                      title: 'Math Problem',
                      icon: Icons.calculate,
                      color: Colors.blue,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology, color: Colors.purple),
                title: const Text('Memory Match'),
                subtitle: const Text('Memorize and recall a sequence.'),
                trailing: _missionSettings.mission == 'memory' ? const Icon(Icons.check, color: Colors.purple) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => DefaultMissionConfigScreen(
                      initialSettings: _missionSettings,
                      missionId: 'memory',
                      title: 'Memory Match',
                      icon: Icons.psychology,
                      color: Colors.purple,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard, color: Colors.indigo),
                title: const Text('Typing'),
                subtitle: const Text('Type a motivational phrase.'),
                trailing: _missionSettings.mission == 'typing' ? const Icon(Icons.check, color: Colors.indigo) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => TypingConfigScreen(
                      initialSettings: _missionSettings,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_view, color: Colors.teal),
                title: const Text('Color Tiles'),
                subtitle: const Text('Find all tiles of a target color.'),
                trailing: _missionSettings.mission == 'color_tiles' ? const Icon(Icons.check, color: Colors.teal) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => DefaultMissionConfigScreen(
                      initialSettings: _missionSettings,
                      missionId: 'color_tiles',
                      title: 'Color Tiles',
                      icon: Icons.grid_view,
                      color: Colors.teal,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_mark, color: Colors.orange),
                title: const Text('Missing Symbol'),
                subtitle: const Text('Find the missing math operator.'),
                trailing: _missionSettings.mission == 'missing_symbol' ? const Icon(Icons.check, color: Colors.orange) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => DefaultMissionConfigScreen(
                      initialSettings: _missionSettings,
                      missionId: 'missing_symbol',
                      title: 'Missing Symbol',
                      icon: Icons.question_mark,
                      color: Colors.orange,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.vibration, color: Colors.redAccent),
                title: const Text('Shake'),
                subtitle: const Text('Shake your phone vigorously.'),
                trailing: _missionSettings.mission == 'shake' ? const Icon(Icons.check, color: Colors.redAccent) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => ShakeConfigScreen(
                      initialSettings: _missionSettings,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.pink),
                title: const Text('QR / Barcode'),
                subtitle: const Text('Scan a specific barcode to wake up.'),
                trailing: _missionSettings.mission == 'qr' ? const Icon(Icons.check, color: Colors.pink) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => QRConfigScreen(
                      initialSettings: _missionSettings,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk, color: Colors.blueAccent),
                title: const Text('Steps'),
                subtitle: const Text('Walk a target number of steps.'),
                trailing: _missionSettings.mission == 'steps' ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<MissionSettings>(
                    context,
                    MaterialPageRoute(builder: (context) => StepsConfigScreen(
                      initialSettings: _missionSettings,
                    )),
                  );
                  if (result != null) setState(() => _missionSettings = result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swipe, color: Colors.green),
                title: const Text('None'),
                subtitle: const Text('Just slide to turn off the alarm.'),
                trailing: _missionSettings.mission == 'none' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => _missionSettings = _missionSettings.copyWith(mission: 'none'));
                  Navigator.pop(context);
                },
              ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildTimeButton(String label, Duration duration) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      onPressed: () => _addTime(duration),
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    String displayTime = "00:00";
    String ringsAt = "Set a timer";
    
    if (_targetTime != null && _targetTime!.isAfter(DateTime.now())) {
      final diff = _targetTime!.difference(DateTime.now());
      int h = diff.inHours;
      int m = diff.inMinutes.remainder(60);
      
      if (h > 0) {
        displayTime = "${h}h ${m}m";
      } else {
        displayTime = "${m}m";
      }
      
      ringsAt = "Rings at ${DateFormat('h:mm a').format(_targetTime!)}";
    } else if (_targetTime != null) {
      // Past time (very rare unless they sat on the screen for a while)
      _targetTime = null;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Quick Alarm"),
        backgroundColor: Colors.transparent,
        actions: [
          if (_targetTime != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetTime,
              tooltip: "Reset Timer",
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  ),
                  child: Column(
                    children: [
                      Text(
                        displayTime,
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimaryContainer,
                          letterSpacing: -2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ringsAt,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Add Time Buttons
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildTimeButton("+1m", const Duration(minutes: 1)),
                    _buildTimeButton("+5m", const Duration(minutes: 5)),
                    _buildTimeButton("+10m", const Duration(minutes: 10)),
                    _buildTimeButton("+15m", const Duration(minutes: 15)),
                    _buildTimeButton("+30m", const Duration(minutes: 30)),
                    _buildTimeButton("+1h", const Duration(hours: 1)),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Exact Time Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                  ),
                  icon: const Icon(Icons.access_time),
                  label: const Text("Set Exact Time"),
                  onPressed: _pickExactTime,
                ),
                
                const SizedBox(height: 32),
                
                // Mission Selection
                PlatformCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alarm Mission', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.psychology, color: Colors.purpleAccent),
                        title: const Text('Mission'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getMissionDisplayName(_missionSettings.mission),
                              style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                          ],
                        ),
                        onTap: _showMissionPicker,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Sound & Vibrate
                PlatformCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.music_note, color: colorScheme.primary),
                        title: const Text('Sound'),
                        trailing: Text(
                          _assetAudio.split('/').last.split('.').first,
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(_volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up), color: colorScheme.onSurfaceVariant),
                            Expanded(
                              child: Slider(
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: colorScheme.primary,
                                onChanged: (val) => setState(() => _volume = val),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      SwitchListTile(
                        secondary: Icon(Icons.vibration, color: colorScheme.primary),
                        title: const Text('Vibrate'),
                        activeThumbColor: colorScheme.primary,
                        value: _vibrate,
                        onChanged: (val) {
                          Haptics.vibrate(HapticsType.selection);
                          setState(() => _vibrate = val);
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Start Button
                ElevatedButton(
                  onPressed: _saveQuickAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.brightness == Brightness.light ? AppTokens.signal.withValues(alpha: 0.15) : AppTokens.signal,
                    foregroundColor: colorScheme.brightness == Brightness.light ? AppTokens.signalDeep : AppTokens.nightBg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      side: colorScheme.brightness == Brightness.light ? BorderSide(color: AppTokens.signal.withValues(alpha: 0.3), width: 1) : BorderSide.none,
                    ),
                  ),
                  child: const Text('START QUICK ALARM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
