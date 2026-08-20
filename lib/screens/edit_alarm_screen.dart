import 'dart:async';
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
import '../services/alarm_announcement_service.dart';

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
  final DateTime? initialTime;
  final String? initialMission;
  final double? initialSleepGoal;

  const EditAlarmScreen({
    Key? key,
    this.alarm,
    this.isWakeRoutine = true,
    this.initialTime,
    this.initialMission,
    this.initialSleepGoal,
  }) : super(key: key);

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
  late MissionSettings _missionSettings; // Kept for config screens compatibility - represents mission 1 of the chain
  // Missions 2-5 of the chain (mission 1 always lives in _missionSettings so
  // the existing single-mission picker/config screens stay untouched).
  List<MissionConfig> _extraMissions = [];
  late RingAnnouncementMode _announcementMode;
  // Independently selectable readout components.
  late bool _announceDay;
  late bool _announceDate;
  late bool _announceTime;
  late bool _announceWeather;

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
    AlarmAnnouncementService.stop();
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
      _extraMissions = widget.alarm!.missions.length > 1 ? List.from(widget.alarm!.missions.sublist(1)) : [];
      _announcementMode = widget.alarm!.announcementMode;
      _announceDay = widget.alarm!.announceDay;
      _announceDate = widget.alarm!.announceDate;
      _announceTime = widget.alarm!.announceTime;
      _announceWeather = widget.alarm!.announceWeather;
    } else {
      if (widget.initialTime != null) {
        final now = DateTime.now();
        selectedDateTime = DateTime(now.year, now.month, now.day, widget.initialTime!.hour, widget.initialTime!.minute);
        if (selectedDateTime.isBefore(now)) {
          selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        }
      } else {
        selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
        selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      }
      loopAudio = true;
      vibrate = true;
      volume = 0.8;
      soundId = 'wakely_soft_morning';
      fadeIn = false;
      fadeDuration = 30;
      _missionSettings = MissionSettings(
        type: widget.isWakeRoutine ? "wakeRoutine" : "alarm",
        mission: widget.initialMission ?? 'memory',
        sleepGoal: widget.initialSleepGoal ?? 8.0,
      );
      _labelController.text = '';
      _selectedDays = List.filled(7, false); // default to one-shot
      _extraMissions = [];
      _announcementMode = RingAnnouncementMode.off;
      _announceDay = true;
      _announceDate = true;
      _announceTime = true;
      _announceWeather = true;
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
    // A chain only makes sense once there's a primary mission - if the
    // user picked 'None', ignore any leftover extra steps rather than
    // shipping a mission-less alarm that somehow still gates on a chain.
    final missionChain = missionConfig.type == MissionType.none ? <MissionConfig>[] : [missionConfig, ..._extraMissions];

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
        missions: missionChain,
        announcementMode: _announcementMode,
        announceDay: _announceDay,
        announceDate: _announceDate,
        announceTime: _announceTime,
        announceWeather: _announceWeather,
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
        missions: missionChain,
        announcementMode: _announcementMode,
        announceDay: _announceDay,
        announceDate: _announceDate,
        announceTime: _announceTime,
        announceWeather: _announceWeather,
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
      unawaited(AlarmAnnouncementService.stop());
      setState(() => _isPreviewing = false);
      return;
    }

    // The ring announcement is part of what this alarm actually sounds
    // like, so "Preview Alarm" wasn't a real preview without it — this was
    // silently missing before.
    if (_announcementMode != RingAnnouncementMode.off) {
      unawaited(AlarmAnnouncementService.maybeSpeak(
        alarmId: widget.alarm?.id ?? -1,
        announcementMode: _announcementMode.toStringValue(),
        announceDay: _announceDay,
        announceDate: _announceDate,
        announceTime: _announceTime,
        announceWeather: _announceWeather,
        forcePreview: true,
      ));
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

  /// The 8 real mission types (+ optional 'None'), each wired to its own
  /// config screen. Shared by the primary mission picker and the "add
  /// another mission" picker for extra chain steps, so both stay in sync
  /// instead of drifting into two copies of the same list.
  List<Widget> _missionOptionTiles({
    required MissionSettings baseSettings,
    required String? selectedType,
    required void Function(MissionSettings result) onPicked,
    bool includeNone = true,
  }) {
    Widget tile({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required String type,
      required Widget Function() buildConfigScreen,
    }) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selectedType == type ? Icon(Icons.check, color: color) : null,
        onTap: () async {
          Navigator.pop(context);
          final result = await Navigator.push<MissionSettings>(
            context,
            MaterialPageRoute(builder: (context) => buildConfigScreen()),
          );
          if (result != null) onPicked(result);
        },
      );
    }

    return [
      tile(
        icon: Icons.calculate, color: Colors.blue, title: 'Math Problem', subtitle: 'Solve a math equation to wake up.', type: 'math',
        buildConfigScreen: () => DefaultMissionConfigScreen(initialSettings: baseSettings, missionId: 'math', title: 'Math Problem', icon: Icons.calculate, color: Colors.blue),
      ),
      tile(
        icon: Icons.psychology, color: Colors.purple, title: 'Memory Match', subtitle: 'Memorize and recall a sequence.', type: 'memory',
        buildConfigScreen: () => DefaultMissionConfigScreen(initialSettings: baseSettings, missionId: 'memory', title: 'Memory Match', icon: Icons.psychology, color: Colors.purple),
      ),
      tile(
        icon: Icons.keyboard, color: Colors.indigo, title: 'Typing', subtitle: 'Type a motivational phrase.', type: 'typing',
        buildConfigScreen: () => TypingConfigScreen(initialSettings: baseSettings),
      ),
      tile(
        icon: Icons.grid_view, color: Colors.teal, title: 'Color Tiles', subtitle: 'Find all tiles of a target color.', type: 'color_tiles',
        buildConfigScreen: () => DefaultMissionConfigScreen(initialSettings: baseSettings, missionId: 'color_tiles', title: 'Color Tiles', icon: Icons.grid_view, color: Colors.teal),
      ),
      tile(
        icon: Icons.question_mark, color: Colors.orange, title: 'Missing Symbol', subtitle: 'Find the missing math operator.', type: 'missing_symbol',
        buildConfigScreen: () => DefaultMissionConfigScreen(initialSettings: baseSettings, missionId: 'missing_symbol', title: 'Missing Symbol', icon: Icons.question_mark, color: Colors.orange),
      ),
      tile(
        icon: Icons.vibration, color: Colors.redAccent, title: 'Shake', subtitle: 'Shake your phone vigorously.', type: 'shake',
        buildConfigScreen: () => ShakeConfigScreen(initialSettings: baseSettings),
      ),
      tile(
        icon: Icons.qr_code_scanner, color: Colors.pink, title: 'QR / Barcode', subtitle: 'Scan a specific barcode to wake up.', type: 'qr',
        buildConfigScreen: () => QRConfigScreen(initialSettings: baseSettings),
      ),
      tile(
        icon: Icons.directions_walk, color: Colors.blueAccent, title: 'Steps', subtitle: 'Walk a target number of steps.', type: 'steps',
        buildConfigScreen: () => StepsConfigScreen(initialSettings: baseSettings),
      ),
      if (includeNone)
        ListTile(
          leading: const Icon(Icons.swipe, color: Colors.green),
          title: const Text('None'),
          subtitle: const Text('Just slide to turn off the alarm.'),
          trailing: selectedType == 'none' ? const Icon(Icons.check, color: Colors.green) : null,
          onTap: () {
            Navigator.pop(context);
            onPicked(baseSettings.copyWith(mission: 'none'));
          },
        ),
    ];
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
                ..._missionOptionTiles(
                  baseSettings: _missionSettings,
                  selectedType: _missionSettings.mission,
                  onPicked: (result) => setState(() {
                    _missionSettings = result;
                    // 'None' as the primary mission means no mission at
                    // all - a chain of follow-ups only makes sense once
                    // there's a first mission leading it.
                    if (result.mission == 'none') _extraMissions = [];
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addExtraMission() {
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Add Mission ${_extraMissions.length + 2} of 5', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ..._missionOptionTiles(
                  baseSettings: MissionSettings(mission: 'memory'),
                  selectedType: null,
                  includeNone: false,
                  onPicked: (result) => setState(() {
                    _extraMissions.add(MissionConfig(
                      type: MissionType.fromString(result.mission),
                      difficultyMode: result.difficultyMode,
                      difficultyOverride: result.difficultyOverride,
                      rounds: result.missionRounds,
                      data: result.missionData,
                    ));
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtraMissionRow(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final m = _extraMissions[index];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: AppTokens.signal.withValues(alpha: 0.15),
        child: Text('${index + 2}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTokens.signal)),
      ),
      title: Text(_getMissionDisplayName(m.type.toStringValue())),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_up, color: index > 0 ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.25)),
            onPressed: index > 0
                ? () => setState(() {
                      final item = _extraMissions.removeAt(index);
                      _extraMissions.insert(index - 1, item);
                    })
                : null,
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down, color: index < _extraMissions.length - 1 ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.25)),
            onPressed: index < _extraMissions.length - 1
                ? () => setState(() {
                      final item = _extraMissions.removeAt(index);
                      _extraMissions.insert(index + 1, item);
                    })
                : null,
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.error),
            onPressed: () => setState(() => _extraMissions.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementPicker() {
    final options = <(RingAnnouncementMode, IconData, String, String)>[
      (RingAnnouncementMode.off, Icons.voice_over_off, 'Off', 'Just the alarm sound, like today.'),
      (RingAnnouncementMode.voiceOnly, Icons.record_voice_over, 'Voice readout only', 'A spoken readout instead of the alarm tone.'),
      (RingAnnouncementMode.voiceAndTone, Icons.graphic_eq, 'Voice readout + tone', 'The spoken readout plays alongside the normal alarm sound.'),
    ];
    bool isPreviewingAnnouncement = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;
            final enabled = _announcementMode != RingAnnouncementMode.off;

            Widget componentToggle({
              required IconData icon,
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return SwitchListTile(
                secondary: Icon(icon, color: enabled ? AppTokens.signal : colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                title: Text(title),
                subtitle: Text(subtitle),
                activeThumbColor: AppTokens.signal,
                value: value,
                onChanged: enabled
                    ? (v) {
                        setSheetState(() {});
                        setState(() => onChanged(v));
                      }
                    : null,
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Ring Announcement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    for (final option in options)
                      ListTile(
                        leading: Icon(option.$2, color: AppTokens.signal),
                        title: Text(option.$3),
                        subtitle: Text(option.$4),
                        trailing: _announcementMode == option.$1 ? Icon(Icons.check, color: AppTokens.signal) : null,
                        onTap: () {
                          setSheetState(() {});
                          setState(() => _announcementMode = option.$1);
                        },
                      ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Text('WHAT TO SAY', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                    componentToggle(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Day',
                      subtitle: 'e.g. "Thursday"',
                      value: _announceDay,
                      onChanged: (v) => _announceDay = v,
                    ),
                    componentToggle(
                      icon: Icons.calendar_today_outlined,
                      title: 'Date',
                      subtitle: 'e.g. "August 20"',
                      value: _announceDate,
                      onChanged: (v) => _announceDate = v,
                    ),
                    componentToggle(
                      icon: Icons.access_time,
                      title: 'Time',
                      subtitle: 'e.g. "10:36 AM"',
                      value: _announceTime,
                      onChanged: (v) => _announceTime = v,
                    ),
                    componentToggle(
                      icon: Icons.cloud_outlined,
                      title: 'Weather',
                      subtitle: 'Only when a recent reading is available',
                      value: _announceWeather,
                      onChanged: (v) => _announceWeather = v,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: !enabled
                              ? null
                              : () async {
                                  setSheetState(() => isPreviewingAnnouncement = true);
                                  await AlarmAnnouncementService.maybeSpeak(
                                    alarmId: widget.alarm?.id ?? -1,
                                    announcementMode: _announcementMode.toStringValue(),
                                    announceDay: _announceDay,
                                    announceDate: _announceDate,
                                    announceTime: _announceTime,
                                    announceWeather: _announceWeather,
                                    forcePreview: true,
                                  );
                                  setSheetState(() => isPreviewingAnnouncement = false);
                                },
                          icon: Icon(isPreviewingAnnouncement ? Icons.stop_circle : Icons.play_circle_fill, color: enabled ? AppTokens.signal : colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          label: Text(
                            isPreviewingAnnouncement ? 'Speaking…' : 'Preview Announcement',
                            style: TextStyle(color: enabled ? AppTokens.signal : colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: (enabled ? AppTokens.signal : colorScheme.onSurfaceVariant).withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => AlarmAnnouncementService.stop());
  }

  String _announcementDisplayName(RingAnnouncementMode mode) {
    switch (mode) {
      case RingAnnouncementMode.off:
        return 'Off';
      case RingAnnouncementMode.voiceOnly:
        return 'Voice only';
      case RingAnnouncementMode.voiceAndTone:
        return 'Voice + tone';
    }
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
                            if (_missionSettings.mission != 'none') ...[
                              const Divider(height: 1),
                              for (int i = 0; i < _extraMissions.length; i++) _buildExtraMissionRow(i),
                              if (_extraMissions.length < 4)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.add_circle_outline, color: AppTokens.signal),
                                  title: Text(
                                    'Add mission ${_extraMissions.length + 2} of 5',
                                    style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  onTap: _addExtraMission,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Ring announcement (spoken time/date/weather readout)
                    PlatformCard(
                      child: ListTile(
                        leading: Icon(Icons.record_voice_over, color: AppTokens.signal),
                        title: const Text('Ring Announcement'),
                        subtitle: const Text('Speak the time, date, and weather when this alarm rings.'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _announcementDisplayName(_announcementMode),
                              style: TextStyle(color: AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                          ],
                        ),
                        onTap: _showAnnouncementPicker,
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
