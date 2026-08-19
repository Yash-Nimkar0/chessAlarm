import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../widgets/platform_theme.dart';
import '../services/sleep_service.dart';
import '../services/elo_service.dart';
import '../services/weather_service.dart';
import '../features/alarms/application/alarm_controller.dart';
import '../features/alarms/domain/alarm_model.dart';
import '../theme/design_tokens.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/breathing_icon.dart';
import '../features/sounds/data/custom_sound_service.dart';
import '../features/sounds/domain/sound_model.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({Key? key}) : super(key: key);

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _isTracking = false;
  ScheduledAlarm? _nextAlarm;
  int _userElo = 1000;
  int _currentStreak = 0;
  int _fastestSolve = 0;
  
  WeatherData? _weatherData;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  List<SoundModel> _customSounds = [];
  bool _isImportingSound = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _isTracking = SleepService.isTracking;
  }

  Future<void> _loadData() async {
    final scheduled = await AlarmController.instance.getNextEnabledWakeRoutine();
    _nextAlarm = scheduled;

    _userElo = await EloService.getElo();
    final stats = await EloService.getStats();
    _currentStreak = stats['currentStreak'] ?? 0;
    _fastestSolve = stats['fastestSolve'] ?? 0;

    _weatherData = await WeatherService.getCurrentWeather();
    _customSounds = await CustomSoundService.getCustomSounds();

    if (mounted) setState(() {});
  }

  Future<void> _importCustomSound() async {
    if (_isImportingSound) return;
    setState(() => _isImportingSound = true);
    try {
      final sound = await CustomSoundService.importSound();
      if (sound != null && mounted) {
        setState(() => _customSounds = [..._customSounds, sound]);
        Haptics.vibrate(HapticsType.success);
      }
    } finally {
      if (mounted) setState(() => _isImportingSound = false);
    }
  }

  Future<void> _deleteCustomSound(SoundModel sound) async {
    if (_currentlyPlaying == sound.name) {
      await _audioPlayer.stop();
      _currentlyPlaying = null;
    }
    await CustomSoundService.deleteCustomSound(sound.id);
    if (mounted) {
      setState(() => _customSounds = _customSounds.where((s) => s.id != sound.id).toList());
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleTracking() async {
    Haptics.vibrate(HapticsType.medium);
    if (_isTracking) {
      final session = await SleepService.stopTracking();
      WakelockPlus.disable();
      setState(() => _isTracking = false);
      if (session != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sleep tracked! Score: ${session.score}/100'),
          backgroundColor: AppTokens.signal,
        ));
      }
    } else {
      try {
        await SleepService.startTracking();
        WakelockPlus.enable();
        if (mounted) setState(() => _isTracking = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Could not start sleep tracking. Check microphone permission and try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
      }
    }
  }

  void _toggleAudio(String name, Source source) async {
    if (_currentlyPlaying == name) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlaying = null);
    } else {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(source);
      setState(() => _currentlyPlaying = name);
    }
  }

  String _formatTime(DateTime time) {
    String hour = time.hour > 12 ? '${time.hour - 12}' : (time.hour == 0 ? '12' : '${time.hour}');
    String min = time.minute.toString().padLeft(2, '0');
    String ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  String _formatTimeLeft(Duration duration) {
    if (duration.isNegative) return "Past bedtime";
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  
  Widget _buildTomorrowPreview() {
     if (_weatherData == null || _weatherData!.hourly.isEmpty) return const SizedBox.shrink();
     
     // Find weather at wake time
     DateTime target = _nextAlarm?.nextOccurrence ?? DateTime.now().add(const Duration(hours: 8));
     
     HourlyForecast? morningForecast;
     for (var h in _weatherData!.hourly) {
        if (h.time.isAfter(target.subtract(const Duration(minutes: 30))) && h.time.isBefore(target.add(const Duration(hours: 2)))) {
           morningForecast = h;
           break;
        }
     }
     
     if (morningForecast == null) return const SizedBox.shrink();
     
     // Pseudo-logic to convert code back to icon/string without bloating
     String weatherStr = "Clear";
     IconData icon = Icons.wb_sunny;
     if (morningForecast.weatherCode >= 51 && morningForecast.weatherCode <= 67) { weatherStr = "Light rain expected"; icon = Icons.water_drop; }
     if (morningForecast.weatherCode >= 71) { weatherStr = "Cold morning"; icon = Icons.ac_unit; }

     return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
           borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
           children: [
              Icon(icon, size: 32, color: AppTokens.signal),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text("Tomorrow Morning", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                       Text("${morningForecast.temperature.floor()}°C", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                       Text(weatherStr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                    ]
                 )
              )
           ]
        )
     );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWakeRoutine = _nextAlarm != null;
    
    return PlatformScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Tonight',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              
              if (_nextAlarm == null)
                FadeSlideIn(child: _buildNoRoutineCard(context))
              else ...[
                // Next Wake Header
                FadeSlideIn(
                  child: isWakeRoutine
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formatTimeLeft(_nextAlarm!.nextOccurrence.subtract(Duration(minutes: (_nextAlarm!.alarm.sleepGoal * 60).toInt())).difference(DateTime.now())),
                                  style: AppTokens.display.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: _nextAlarm!.nextOccurrence.subtract(Duration(minutes: (_nextAlarm!.alarm.sleepGoal * 60).toInt())).difference(DateTime.now()).isNegative ? AppTokens.signal : Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'until bedtime',
                                  style: TextStyle(color: AppTokens.signal, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Wake up at ${_formatTime(_nextAlarm!.nextOccurrence)}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(_formatTime(_nextAlarm!.nextOccurrence), style: AppTokens.display.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                                const SizedBox(width: 12),
                                Text(
                                  'Quick Alarm',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Time until wake: ${_nextAlarm!.nextOccurrence.difference(DateTime.now()).inHours}h ${_nextAlarm!.nextOccurrence.difference(DateTime.now()).inMinutes % 60}m',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                        ],
                      ),
                ),

                const SizedBox(height: 32),

                FadeSlideIn(delay: const Duration(milliseconds: 70), child: _buildTomorrowPreview()),

                if (isWakeRoutine) ...[
                  // Tomorrow's Mission
                  FadeSlideIn(delay: const Duration(milliseconds: 140), child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Tomorrow's Mission",
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTokens.signal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                              child: Text('$_userElo Points', style: const TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(_fastestSolve > 0 ? "Goal: Beat $_fastestSolve seconds" : "Goal: Complete your first mission!", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: AppTokens.signal, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "Streak: $_currentStreak days",
                                style: const TextStyle(color: AppTokens.signal, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 24),

                  // Sleep Readiness Checklist
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 210),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sleep Readiness', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildChecklistItem(Icons.alarm_on, 'Alarm armed for ${_formatTime(_nextAlarm!.nextOccurrence)}'),
                        _buildChecklistItem(Icons.bedtime, 'Sleep goal: ${_nextAlarm!.alarm.sleepGoal}h'),
                        _buildChecklistItem(Icons.psychology, 'Challenge loaded'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ],

              // Sleep tracking and relax sounds are useful regardless of
              // whether a wake routine is scheduled tonight — they used to
              // live inside the "else" branch above, which meant having no
              // alarm set hid real, always-relevant features (not just an
              // empty state) behind an unrelated condition.
              if (_nextAlarm == null) const SizedBox(height: 8),

              // Sleep Tracking Magic Button
              FadeSlideIn(delay: const Duration(milliseconds: 280), child: AnimatedPressable(
                  onTap: _toggleTracking,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: _isTracking 
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : (Theme.of(context).brightness == Brightness.light
                              ? AppTokens.signal.withValues(alpha: 0.15)
                              : AppTokens.signal),
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: _isTracking 
                          ? Border.all(color: AppTokens.signal, width: 2)
                          : (Theme.of(context).brightness == Brightness.light ? Border.all(color: AppTokens.signal.withValues(alpha: 0.3), width: 1) : null),
                      boxShadow: [
                        if (!_isTracking && Theme.of(context).brightness == Brightness.dark) 
                          BoxShadow(color: AppTokens.signal.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isTracking ? Icons.nights_stay : Icons.bedtime, 
                          color: _isTracking ? AppTokens.signal : (Theme.of(context).brightness == Brightness.light ? AppTokens.signalDeep : AppTokens.nightBg), 
                          size: 32
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isTracking ? 'Sleep Mode Active' : 'Start Sleep Mode',
                          style: TextStyle(
                            color: _isTracking ? AppTokens.signal : (Theme.of(context).brightness == Brightness.light ? AppTokens.signalDeep : AppTokens.nightBg), 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (_isTracking)
                           const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text("✓ Tracking active", style: TextStyle(color: AppTokens.signal, fontSize: 12))
                           )
                      ],
                    ),
                  ),
                ),
              ),

                const SizedBox(height: 40),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relax Sounds', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                  height: 108,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildSoundButton(Icons.water_drop, 'Rain', AssetSource('audio/rain.mp3')),
                      const SizedBox(width: 16),
                      _buildSoundButton(Icons.waves, 'Ocean', AssetSource('audio/ocean.mp3')),
                      const SizedBox(width: 16),
                      _buildSoundButton(Icons.forest, 'Jungle', AssetSource('audio/brown_noise.mp3')),
                      const SizedBox(width: 16),
                      _buildSoundButton(Icons.noise_control_off, 'White', AssetSource('audio/white_noise.mp3')),
                      for (final sound in _customSounds) ...[
                        const SizedBox(width: 16),
                        _buildSoundButton(
                          Icons.music_note,
                          sound.name,
                          DeviceFileSource(sound.path),
                          onLongPress: () => _confirmDeleteCustomSound(sound),
                        ),
                      ],
                      const SizedBox(width: 16),
                      _buildAddSoundButton(),
                    ],
                  ),
                ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoRoutineCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Column(
        children: [
          BreathingIcon(
            icon: Icons.nightlight_round,
            color: AppTokens.signal,
            backgroundColor: AppTokens.signal.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No wake routine set for tonight',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Set one from the Alarm tab to see your countdown, mission preview, and sleep readiness here.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(IconData icon, String text) {
     return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
           children: [
              Icon(icon, color: AppTokens.signal, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
           ]
        )
     );
  }

  Widget _buildSoundButton(IconData icon, String name, Source source, {VoidCallback? onLongPress}) {
    bool isPlaying = _currentlyPlaying == name;
    return AnimatedPressable(
      onTap: () {
         Haptics.vibrate(HapticsType.light);
         _toggleAudio(name, source);
      },
      onLongPress: onLongPress,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isPlaying ? AppTokens.signal.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPlaying ? AppTokens.signal : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isPlaying
                    ? [BoxShadow(color: AppTokens.signal.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Center(
                child: isPlaying
                    ? _PlayingPulseIcon(icon: icon, color: AppTokens.signal)
                    : Icon(icon, size: 32, color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isPlaying ? AppTokens.signal : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSoundButton() {
    return AnimatedPressable(
      onTap: _importCustomSound,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: _isImportingSound
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      )
                    : Icon(Icons.add, size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Text('Add', maxLines: 1, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCustomSound(SoundModel sound) {
    Haptics.vibrate(HapticsType.medium);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sound?'),
        content: Text('"${sound.name}" will be removed from your relax sounds.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCustomSound(sound);
            },
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

/// A gentle breathing scale on a sound's icon while it's actively
/// playing — a small "this is alive" signal that a static icon plus a
/// colored border alone doesn't give.
class _PlayingPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PlayingPulseIcon({required this.icon, required this.color});

  @override
  State<_PlayingPulseIcon> createState() => _PlayingPulseIconState();
}

class _PlayingPulseIconState extends State<_PlayingPulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Icon(widget.icon, size: 32, color: widget.color),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(scale: 0.92 + (0.16 * t), child: child);
      },
    );
  }
}
