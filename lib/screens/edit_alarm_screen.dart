import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/mission_settings.dart';
import '../widgets/platform_theme.dart';

class EditAlarmScreen extends StatefulWidget {
  final AlarmSettings? alarmSettings;
  final bool isWakeRoutine;
  const EditAlarmScreen({Key? key, this.alarmSettings, this.isWakeRoutine = true}) : super(key: key);

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late DateTime selectedDateTime;
  late bool loopAudio;
  late bool vibrate;
  late double volume;
  late String assetAudio;
  late MissionSettings _missionSettings;
  
  late int _alarmId;
  
  // 0=Mon, 1=Tue, ..., 6=Sun
  List<bool> _selectedDays = List.filled(7, false);
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _alarmId = widget.alarmSettings?.id ?? Random().nextInt(10000) + 1;
    
    if (widget.alarmSettings != null) {
      selectedDateTime = widget.alarmSettings!.dateTime;
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      volume = widget.alarmSettings!.volumeSettings.volume ?? 0.8;
      assetAudio = widget.alarmSettings!.assetAudioPath ?? 'assets/marimba.mp3';
      
      if (widget.alarmSettings!.payload != null) {
        _missionSettings = MissionSettings.fromJsonString(widget.alarmSettings!.payload!);
      } else {
        _missionSettings = MissionSettings(type: widget.isWakeRoutine ? "wakeRoutine" : "quickAlarm");
      }
    } else {
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = 0.8;
      assetAudio = 'assets/marimba.mp3';
      _missionSettings = MissionSettings(type: widget.isWakeRoutine ? "wakeRoutine" : "quickAlarm");
    }
    
    _loadRecurringDays();
  }
  
  Future<void> _loadRecurringDays() async {
    final prefs = await SharedPreferences.getInstance();
    final String? daysJson = prefs.getString('alarm_days_$_alarmId');
    if (daysJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(daysJson);
        setState(() {
          _selectedDays = decoded.map((e) => e as bool).toList();
        });
      } catch (e) {
        // Ignore
      }
    }
  }
  
  Future<void> _saveRecurringDays() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_days_$_alarmId', jsonEncode(_selectedDays));
  }

  DateTime _calculateNextOccurrence(DateTime time, List<bool> days) {
    if (!days.contains(true)) {
      // One-off alarm
      if (time.isBefore(DateTime.now())) {
        return time.add(const Duration(days: 1));
      }
      return time;
    }
    
    // Find the next active day
    DateTime candidate = time;
    if (candidate.isBefore(DateTime.now())) {
      candidate = candidate.add(const Duration(days: 1));
    }
    
    while (!days[candidate.weekday - 1]) {
      candidate = candidate.add(const Duration(days: 1));
    }
    
    return candidate;
  }

  String getDayAbbreviation(DateTime date) {
    return DateFormat('EEE').format(date);
  }

  void saveAlarm() async {
    Haptics.vibrate(HapticsType.medium);
    
    DateTime nextTime = _calculateNextOccurrence(selectedDateTime, _selectedDays);

    final alarmSettings = AlarmSettings(
      id: _alarmId,
      dateTime: nextTime,
      assetAudioPath: assetAudio,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volumeSettings: VolumeSettings.fade(
        volume: volume,
        fadeDuration: const Duration(milliseconds: 2000),
      ),
      notificationSettings: NotificationSettings(
        title: widget.isWakeRoutine ? 'Wake Routine' : 'Alarm',
        body: widget.isWakeRoutine ? 'Time to wake up and solve your challenge.' : 'Your alarm is ringing.',
      ),
      payload: _missionSettings.toJsonString(),
    );

    await _saveRecurringDays();
    await Alarm.set(alarmSettings: alarmSettings);
    
    if (mounted) {
      Navigator.pop(context, alarmSettings);
    }
  }

  void deleteAlarm() async {
    if (widget.alarmSettings != null) {
      Haptics.vibrate(HapticsType.heavy);
      await Alarm.stop(widget.alarmSettings!.id);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_days_${widget.alarmSettings!.id}');
      
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PlatformScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Haptics.vibrate(HapticsType.selection);
                      Navigator.pop(context);
                    },
                    child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
                  ),
                  Text(
                    widget.alarmSettings == null ? 'New Alarm' : 'Edit Alarm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  TextButton(
                    onPressed: saveAlarm,
                    child: Text('Save', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Time Picker (Modernized)
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Brightness.dark,
                          primaryColor: colorScheme.primary,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: selectedDateTime,
                          onDateTimeChanged: (DateTime newDateTime) {
                            Haptics.vibrate(HapticsType.selection);
                            setState(() {
                              selectedDateTime = newDateTime.copyWith(
                                year: selectedDateTime.year,
                                month: selectedDateTime.month,
                                day: selectedDateTime.day,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Repeat Days (Compact bubbles)
                    PlatformCard(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                Text('Repeat', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                                Row(
                                   children: [
                                      GestureDetector(
                                         onTap: () => setState(() => _selectedDays.fillRange(0, 7, true)),
                                         child: Text('Everyday', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                         onTap: () => setState(() { _selectedDays.fillRange(0, 5, true); _selectedDays.fillRange(5, 7, false); }),
                                         child: Text('Weekdays', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                         onTap: () => setState(() { _selectedDays.fillRange(0, 5, false); _selectedDays.fillRange(5, 7, true); }),
                                         child: Text('Weekends', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                                      ),
                                   ]
                                )
                             ]
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              final isSelected = _selectedDays[index];
                              return GestureDetector(
                                onTap: () {
                                  Haptics.vibrate(HapticsType.selection);
                                  setState(() {
                                    _selectedDays[index] = !_selectedDays[index];
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _dayLabels[index],
                                    style: TextStyle(
                                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    
                    if (widget.isWakeRoutine)
                      PlatformCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Wake Routine Settings', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bedtime, color: Colors.blueAccent),
                              title: const Text('Sleep Goal'),
                              trailing: Text('8 Hours', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            _buildMissionTile(colorScheme),
                          ],
                        ),
                      )
                    else
                      PlatformCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Task Settings', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildMissionTile(colorScheme),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    // Sound & Vibrate settings
                    PlatformCard(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.music_note, color: colorScheme.primary),
                            title: const Text('Sound'),
                            trailing: Text(
                              assetAudio.split('/').last.split('.').first,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(volume == 0 ? Icons.volume_off : (volume < 0.5 ? Icons.volume_down : Icons.volume_up), color: colorScheme.onSurfaceVariant),
                                Expanded(
                                  child: Slider(
                                    value: volume,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: colorScheme.primary,
                                    onChanged: (val) => setState(() => volume = val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          SwitchListTile(
                            secondary: Icon(Icons.vibration, color: colorScheme.primary),
                            title: const Text('Vibrate'),
                            activeColor: colorScheme.primary,
                            value: vibrate,
                            onChanged: (val) {
                              Haptics.vibrate(HapticsType.selection);
                              setState(() => vibrate = val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (widget.alarmSettings != null)
                      TextButton.icon(
                        icon: Icon(Icons.delete_outline, color: colorScheme.error),
                        label: Text('Delete Alarm', style: TextStyle(color: colorScheme.error, fontSize: 16)),
                        onPressed: deleteAlarm,
                      ),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMissionTile(ColorScheme colorScheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.psychology, color: Colors.purpleAccent),
      title: const Text('Mission'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_missionSettings.mission == 'chess' ? 'Chess Puzzle' : 'None', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text("Select Task")),
              ListTile(
                title: const Text("Chess Puzzle"),
                trailing: _missionSettings.mission == 'chess' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                onTap: () {
                  setState(() {
                    _missionSettings = _missionSettings.copyWith(mission: 'chess');
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text("None (Just ring)"),
                trailing: _missionSettings.mission == 'none' ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                onTap: () {
                  setState(() {
                    _missionSettings = _missionSettings.copyWith(mission: 'none');
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
