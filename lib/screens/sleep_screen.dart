import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../widgets/platform_theme.dart';
import '../services/sleep_service.dart';
import '../services/elo_service.dart';
import '../services/weather_service.dart';
import '../models/mission_settings.dart';
import '../theme/design_tokens.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({Key? key}) : super(key: key);

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _isTracking = false;
  AlarmSettings? _nextAlarm;
  MissionSettings? _missionSettings;
  int _userElo = 1000;
  int _currentStreak = 0;
  int _fastestSolve = 0;
  
  WeatherData? _weatherData;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadData();
    _isTracking = SleepService.isTracking;
  }

  Future<void> _loadData() async {
    final alarms = await Alarm.getAlarms();
    if (alarms.isNotEmpty) {
      alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      _nextAlarm = alarms.firstWhere((a) => a.dateTime.isAfter(DateTime.now()), orElse: () => alarms.first);
      if (_nextAlarm?.payload != null) {
          _missionSettings = MissionSettings.fromJsonString(_nextAlarm!.payload!);
      }
    }
    
    _userElo = await EloService.getElo();
    final stats = await EloService.getStats();
    _currentStreak = stats['currentStreak'] ?? 0;
    _fastestSolve = stats['fastestSolve'] ?? 0;
    
    _weatherData = await WeatherService.getCurrentWeather();
    
    if (mounted) setState(() {});
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
      await SleepService.startTracking();
      WakelockPlus.enable();
      setState(() => _isTracking = true);
    }
  }

  void _toggleAudio(String name, String path) async {
    if (_currentlyPlaying == name) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlaying = null);
    } else {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(path));
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
     DateTime target = _nextAlarm?.dateTime ?? DateTime.now().add(const Duration(hours: 8));
     
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
    final colorScheme = Theme.of(context).colorScheme;
    
    final bool isWakeRoutine = _missionSettings != null && _missionSettings!.type == 'wakeRoutine';
    
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('No alarms set for tonight.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                )
              else ...[
                // Next Wake Header
                if (isWakeRoutine) ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatTimeLeft(_nextAlarm!.dateTime.subtract(Duration(minutes: (_missionSettings!.sleepGoal * 60).toInt())).difference(DateTime.now())),
                          style: AppTokens.display.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: _nextAlarm!.dateTime.subtract(Duration(minutes: (_missionSettings!.sleepGoal * 60).toInt())).difference(DateTime.now()).isNegative ? AppTokens.signal : Theme.of(context).colorScheme.onSurface),
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
                    'Wake up at ${_formatTime(_nextAlarm!.dateTime)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ] else ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_formatTime(_nextAlarm!.dateTime), style: AppTokens.display.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(width: 12),
                        Text(
                          'Quick Alarm',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Time until wake: ${_nextAlarm!.dateTime.difference(DateTime.now()).inHours}h ${_nextAlarm!.dateTime.difference(DateTime.now()).inMinutes % 60}m',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                _buildTomorrowPreview(),
                
                if (isWakeRoutine) ...[
                  // Tomorrow's Mission
                  Container(
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
                            Text("Tomorrow's Mission", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
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
                            Text("Streak: $_currentStreak days", style: const TextStyle(color: AppTokens.signal, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sleep Readiness Checklist
                  Text('Sleep Readiness', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildChecklistItem(Icons.alarm_on, 'Alarm armed for ${_formatTime(_nextAlarm!.dateTime)}'),
                  _buildChecklistItem(Icons.bedtime, 'Sleep goal: ${_missionSettings!.sleepGoal}h'),
                  _buildChecklistItem(Icons.psychology, 'Challenge loaded'),
                  
                  const SizedBox(height: 32),
                ],
                
                // Sleep Tracking Magic Button
                GestureDetector(
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
                          _isTracking ? 'Hardcore Wake Active' : 'Start Sleep Mode',
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
                
                const SizedBox(height: 40),
                Text('Relax Sounds', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSoundButton(Icons.water_drop, 'Rain', 'audio/rain.mp3'),
                    _buildSoundButton(Icons.waves, 'Ocean', 'audio/ocean.mp3'),
                    _buildSoundButton(Icons.forest, 'Jungle', 'audio/brown_noise.mp3'),
                    _buildSoundButton(Icons.noise_control_off, 'White', 'audio/white_noise.mp3'),
                  ],
                ),
                
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
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
              Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15)),
           ]
        )
     );
  }

  Widget _buildSoundButton(IconData icon, String name, String assetPath) {
    bool isPlaying = _currentlyPlaying == name;
    return GestureDetector(
      onTap: () {
         Haptics.vibrate(HapticsType.light);
         _toggleAudio(name, assetPath);
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isPlaying ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(icon, size: 32, color: isPlaying ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(color: isPlaying ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
