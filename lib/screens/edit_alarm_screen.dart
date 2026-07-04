import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';

class EditAlarmScreen extends StatefulWidget {
  final AlarmSettings? alarmSettings;
  const EditAlarmScreen({Key? key, this.alarmSettings}) : super(key: key);

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late DateTime selectedDateTime;
  late bool loopAudio;
  late bool vibrate;
  late double volume;
  late String assetAudio;

  @override
  void initState() {
    super.initState();
    if (widget.alarmSettings != null) {
      selectedDateTime = widget.alarmSettings!.dateTime;
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      volume = widget.alarmSettings!.volumeSettings.volume ?? 0.8;
      assetAudio = widget.alarmSettings!.assetAudioPath ?? 'assets/marimba.mp3';
    } else {
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = 0.8;
      assetAudio = 'assets/marimba.mp3';
    }
  }

  Future<void> pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1C1C23),
              hourMinuteTextColor: Colors.white,
              dialHandColor: Colors.greenAccent.shade400,
              dialBackgroundColor: Colors.white.withOpacity(0.05),
              dialTextColor: Colors.white70,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        final now = DateTime.now();
        selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
        if (selectedDateTime.isBefore(now)) {
          selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        }
      });
    }
  }

  void saveAlarm() async {
    final alarmSettings = AlarmSettings(
      id: widget.alarmSettings?.id ?? Random().nextInt(10000) + 1,
      dateTime: selectedDateTime,
      assetAudioPath: assetAudio,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volumeSettings: VolumeSettings.fixed(
        volume: volume,
      ),
      notificationSettings: const NotificationSettings(
        title: 'Chess Alarm',
        body: 'Wake up and solve this puzzle!',
      ),
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save alarm. (Error: $e)',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alarmSettings == null ? 'NEW ALARM' : 'EDIT ALARM', 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickTime,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('h:mm').format(selectedDateTime),
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('a').format(selectedDateTime),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.greenAccent,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Vibrate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    trailing: Switch(
                      value: vibrate,
                      activeColor: Colors.greenAccent,
                      onChanged: (value) => setState(() => vibrate = value),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    title: const Text('Loop Audio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    trailing: Switch(
                      value: loopAudio,
                      activeColor: Colors.greenAccent,
                      onChanged: (value) => setState(() => loopAudio = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Volume', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                      Icon(volume > 0.5 ? Icons.volume_up_rounded : Icons.volume_down_rounded, color: Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.greenAccent,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                      overlayColor: Colors.greenAccent.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: volume,
                      onChanged: (value) => setState(() => volume = value),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveAlarm,
                child: const Text('SAVE ALARM'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
