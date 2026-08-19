import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/mission_settings.dart' hide MissionType;
import '../widgets/platform_theme.dart';

import '../features/alarms/domain/alarm_model.dart';
import '../features/alarms/domain/mission_config.dart';
import '../features/alarms/domain/recurrence.dart';
import '../features/alarms/application/alarm_controller.dart';

import 'missions/typing_config_screen.dart';
import 'missions/shake_config_screen.dart';
import 'missions/default_config_screen.dart';
import 'missions/qr_config_screen.dart';
import 'missions/steps_config_screen.dart';
import 'sound_picker_screen.dart';
import '../features/sounds/data/sound_repository.dart';
import '../theme/design_tokens.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/fade_slide_in.dart';

class EditAlarmScreen extends StatefulWidget {
  final WakelyAlarm? alarm;
  final bool isWakeRoutine;
  
  const EditAlarmScreen({Key? key, this.alarm, this.isWakeRoutine = true}) : super(key: key);

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late DateTime selectedDateTime;
  late bool loopAudio;
  late bool vibrate;
  late double volume;
  late String soundId;
  late bool fadeIn;
  late int fadeDuration;
  late MissionSettings _missionSettings; // Kept for config screens compatibility
  
  // 0=Mon, 1=Tue, ..., 6=Sun
  List<bool> _selectedDays = List.filled(7, true);
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final TextEditingController _labelController = TextEditingController();
  AudioPlayer? _audioPlayer;
  bool _isPreviewing = false;

  @override
  void dispose() {
    _labelController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    if (widget.alarm != null) {
      selectedDateTime = widget.alarm!.time;
      loopAudio = widget.alarm!.loopAudio;
      vibrate = widget.alarm!.vibrate;
      volume = widget.alarm!.volume;
      soundId = widget.alarm!.soundId;
      fadeIn = widget.alarm!.fadeIn;
      fadeDuration = widget.alarm!.fadeDuration;
      
      _selectedDays = List.from(widget.alarm!.recurrence.days);
      _labelController.text = widget.alarm!.label ?? '';
      
      // Map domain model back to UI state
      _missionSettings = MissionSettings(
        type: widget.alarm!.type.toStringValue(),
        sleepGoal: widget.alarm!.sleepGoal,
        sleepTracking: widget.alarm!.sleepTracking,
        sleepSounds: widget.alarm!.sleepSounds,
        mission: widget.alarm!.mission.type.toStringValue(),
        difficultyMode: widget.alarm!.mission.difficultyMode,
        difficultyOverride: widget.alarm!.mission.difficultyOverride,
        missionRounds: widget.alarm!.mission.rounds,
        missionData: widget.alarm!.mission.data,
        label: widget.alarm!.label,
        smartLock: widget.alarm!.smartLock,
      );
    } else {
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = 0.8;
      soundId = 'wakely_soft_morning';
      fadeIn = false;
      fadeDuration = 30;
      _missionSettings = MissionSettings(type: widget.isWakeRoutine ? "wakeRoutine" : "alarm");
      _labelController.text = '';
      _selectedDays = List.filled(7, false); // default to one-shot
    }
  }
  
  void saveAlarm() async {
    Haptics.vibrate(HapticsType.medium);
    
    // Safety validation for sound
    final sound = SoundRepository.instance.getSoundById(soundId);
    if (sound == null) {
      soundId = 'wakely_soft_morning'; // fallback cleanly
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected sound was unavailable. Falling back to default.')),
      );
    }
    
    final label = _labelController.text.trim().isNotEmpty ? _labelController.text.trim() : null;
    final recurrence = Recurrence(_selectedDays);

    final missionConfig = MissionConfig(
      type: MissionType.fromString(_missionSettings.mission),
      difficultyMode: _missionSettings.difficultyMode,
      difficultyOverride: _missionSettings.difficultyOverride,
      rounds: _missionSettings.missionRounds,
      data: _missionSettings.missionData,
    );

    final alarmType = widget.isWakeRoutine ? AlarmType.wakeRoutine : AlarmType.standard;

    if (widget.alarm == null) {
      // Create new
      final newAlarm = WakelyAlarm(
        id: 0, // Assigned by controller
        time: selectedDateTime,
        enabled: true,
        type: alarmType,
        recurrence: recurrence,
        label: label,
        soundId: soundId,
        fadeIn: fadeIn,
        fadeDuration: fadeDuration,
        loopAudio: loopAudio,
        vibrate: vibrate,
        volume: volume,
        smartLock: _missionSettings.smartLock,
        mission: missionConfig,
        sleepGoal: _missionSettings.sleepGoal,
        sleepTracking: _missionSettings.sleepTracking,
        sleepSounds: _missionSettings.sleepSounds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final created = await AlarmController.instance.createAlarm(newAlarm);
      if (mounted) Navigator.pop(context, created);
    } else {
      // Update existing
      final updatedAlarm = widget.alarm!.copyWith(
        time: selectedDateTime,
        enabled: true,
        type: alarmType,
        recurrence: recurrence,
        label: label,
        soundId: soundId,
        fadeIn: fadeIn,
        fadeDuration: fadeDuration,
        loopAudio: loopAudio,
        vibrate: vibrate,
        volume: volume,
        smartLock: _missionSettings.smartLock,
        mission: missionConfig,
        sleepGoal: _missionSettings.sleepGoal,
        sleepTracking: _missionSettings.sleepTracking,
        sleepSounds: _missionSettings.sleepSounds,
        updatedAt: DateTime.now(),
      );
      
      final saved = await AlarmController.instance.updateAlarm(updatedAlarm);
      if (mounted) Navigator.pop(context, saved);
    }
  }

  void deleteAlarm() async {
    if (widget.alarm == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Alarm?'),
        content: const Text('This alarm will be permanently removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    Haptics.vibrate(HapticsType.heavy);
    await AlarmController.instance.deleteAlarm(widget.alarm!.id);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _previewAlarm() async {
    if (_isPreviewing) {
      _audioPlayer?.stop();
      setState(() => _isPreviewing = false);
      return;
    }

    final sound = SoundRepository.instance.getSoundById(soundId);
    if (sound == null) return;

    _audioPlayer ??= AudioPlayer();
    await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
    
    // Simplistic handling: set volume
    await _audioPlayer!.setVolume(volume);

    // Fade-in simulation
    if (fadeIn && fadeDuration > 0) {
      _audioPlayer!.setVolume(0.0);
      _audioPlayer!.play(AssetSource(sound.path.replaceAll('assets/', '')));
      
      final steps = 10;
      final stepDuration = fadeDuration * 1000 ~/ steps;
      final volumeStep = volume / steps;
      
      for (int i = 1; i <= steps; i++) {
        if (!mounted || !_isPreviewing) break;
        await Future.delayed(Duration(milliseconds: stepDuration));
        if (!mounted || !_isPreviewing) break;
        await _audioPlayer!.setVolume(volumeStep * i);
      }
    } else {
      await _audioPlayer!.play(AssetSource(sound.path.replaceAll('assets/', '')));
    }

    if (vibrate) {
      Haptics.vibrate(HapticsType.heavy);
    }

    setState(() => _isPreviewing = true);
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
    });
  }

  /// Was previously not wired up at all — the Sleep Goal row displayed a
  /// hardcoded "8 Hours" regardless of the actual value and had no onTap,
  /// so it looked editable (same ListTile pattern as Sound/Mission above
  /// it, which are) but silently did nothing.
  void _showSleepGoalPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleep Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Text(
                      '${_missionSettings.sleepGoal % 1 == 0 ? _missionSettings.sleepGoal.toInt() : _missionSettings.sleepGoal} Hours',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTokens.signal),
                    ),
                    Slider(
                      value: _missionSettings.sleepGoal,
                      min: 4,
                      max: 12,
                      divisions: 16,
                      activeColor: AppTokens.signal,
                      onChanged: (val) {
                        Haptics.vibrate(HapticsType.selection);
                        setSheetState(() {});
                        setState(() => _missionSettings = _missionSettings.copyWith(sleepGoal: val));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    widget.alarm == null ? 'New Alarm' : 'Edit Alarm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  TextButton(
                    onPressed: saveAlarm,
                    child: Text('Save', style: TextStyle(color: AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: FadeSlideIn(child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Time Picker (Modernized)
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      ),
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Brightness.dark,
                          primaryColor: AppTokens.signal,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        child: ExcludeSemantics(
                          // CupertinoDatePicker corrupts the semantics tree
                          // for this entire screen when included: Cancel,
                          // Save, and every other control below it silently
                          // stop being exposed to UIAccessibility (confirmed
                          // by removing it experimentally — everything else
                          // becomes reachable). Excluding it here is a
                          // deliberate tradeoff: the picker itself won't be
                          // individually announced by VoiceOver, but the
                          // rest of the screen — including Save, without
                          // which the alarm can't be created at all — is
                          // reachable again.
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
                    ),
                    const SizedBox(height: 20),

                    // Label Field
                    PlatformCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: TextField(
                        controller: _labelController,
                        decoration: InputDecoration(
                          hintText: 'Label (e.g. Work, Gym)',
                          border: InputBorder.none,
                          icon: Icon(Icons.label_outline, color: colorScheme.onSurfaceVariant),
                        ),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                        cursorColor: AppTokens.signal,
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                      AnimatedPressable(
                                         onTap: () {
                                           Haptics.vibrate(HapticsType.selection);
                                           setState(() => _selectedDays.fillRange(0, 7, true));
                                         },
                                         child: Text('Everyday', style: TextStyle(color: AppTokens.signal, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedPressable(
                                         onTap: () {
                                           Haptics.vibrate(HapticsType.selection);
                                           setState(() { _selectedDays.fillRange(0, 5, true); _selectedDays.fillRange(5, 7, false); });
                                         },
                                         child: Text('Weekdays', style: TextStyle(color: AppTokens.signal, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedPressable(
                                         onTap: () {
                                           Haptics.vibrate(HapticsType.selection);
                                           setState(() { _selectedDays.fillRange(0, 5, false); _selectedDays.fillRange(5, 7, true); });
                                         },
                                         child: Text('Weekends', style: TextStyle(color: AppTokens.signal, fontSize: 12)),
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
                              return AnimatedPressable(
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
                                    color: isSelected ? AppTokens.signal : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _dayLabels[index],
                                    style: TextStyle(
                                      color: isSelected ? AppTokens.nightBg : colorScheme.onSurfaceVariant,
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
                    
                    // Sound settings (Primary)
                    PlatformCard(
                      child: ListTile(
                        leading: Icon(Icons.music_note, color: AppTokens.signal),
                        title: const Text('Sound'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              SoundRepository.instance.getSoundById(soundId)?.name ?? 'Unknown',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SoundPickerScreen(
                                initialSoundId: soundId,
                                initialFadeIn: fadeIn,
                                initialFadeDuration: fadeDuration,
                                onChanged: (result) {
                                  setState(() {
                                    soundId = result.soundId;
                                    fadeIn = result.fadeIn;
                                    fadeDuration = result.fadeDuration;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('Additional Settings', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.isWakeRoutine)
                      PlatformCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wake Routine Settings', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bedtime, color: Colors.blueAccent),
                                title: const Text('Sleep Goal'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_missionSettings.sleepGoal % 1 == 0 ? _missionSettings.sleepGoal.toInt() : _missionSettings.sleepGoal} Hours',
                                      style: TextStyle(color: AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                                  ],
                                ),
                                onTap: _showSleepGoalPicker,
                              ),
                              ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    // Mission Selection (Available for all alarms)
                    PlatformCard(
                      padding: const EdgeInsets.all(16.0),
                      child: Material(
                        type: MaterialType.transparency,
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
                                    style: TextStyle(color: AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold),
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
                    ),

                    const SizedBox(height: 16),
                    // Sound & Vibrate settings
                    PlatformCard(
                      child: Column(
                        children: [
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
                                    activeColor: AppTokens.signal,
                                    onChanged: (val) => setState(() => volume = val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          SwitchListTile(
                            secondary: Icon(Icons.vibration, color: AppTokens.signal),
                            title: const Text('Vibrate'),
                            activeThumbColor: AppTokens.signal,
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

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _isPreviewing ? colorScheme.error : AppTokens.signal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
                        ),
                        icon: Icon(_isPreviewing ? Icons.stop_circle : Icons.play_circle_fill, color: _isPreviewing ? colorScheme.error : AppTokens.signal),
                        label: Text(_isPreviewing ? 'Stop Preview' : 'Preview Alarm', style: TextStyle(color: _isPreviewing ? colorScheme.error : AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _previewAlarm,
                      ),
                    ),

                    if (widget.alarm != null) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: Icon(Icons.delete_outline, color: colorScheme.error),
                        label: Text('Delete Alarm', style: TextStyle(color: colorScheme.error, fontSize: 16)),
                        onPressed: deleteAlarm,
                      ),
                    ],
                      
                    const SizedBox(height: 40),
                  ],
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
