import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:intl/intl.dart';
import '../widgets/platform_theme.dart';
import '../services/sleep_service.dart';
import '../services/elo_service.dart';
import '../services/weather_service.dart';
import '../models/mission_settings.dart';

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
          backgroundColor: Colors.green,
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

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
  
  String _formatDuration(Duration diff) {
    if (diff.isNegative) return "0m";
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    
    if (days > 0) {
      return "$days day${days > 1 ? 's' : ''} and $hours hr${hours != 1 ? 's' : ''}";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
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
     String icon = "☀️";
     if (morningForecast.weatherCode >= 51 && morningForecast.weatherCode <= 67) { weatherStr = "Light rain expected"; icon = "🌧️"; }
     if (morningForecast.weatherCode >= 71) { weatherStr = "Cold morning"; icon = "❄️"; }

     return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
           borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
           children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text("Tomorrow Morning", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                       Text("${morningForecast.temperature.floor()}°C", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                       Text(weatherStr, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
              const Text(
                'Tonight 🌙',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              
              if (_nextAlarm == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No alarms set for tonight.', style: TextStyle(color: Colors.white54)),
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
                          _nextAlarm!.dateTime.subtract(Duration(minutes: (_missionSettings!.sleepGoal * 60).toInt())).difference(DateTime.now()).isNegative ? "Past bedtime" :
                          _formatDuration(_nextAlarm!.dateTime.subtract(Duration(minutes: (_missionSettings!.sleepGoal * 60).toInt())).difference(DateTime.now())),
                          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _nextAlarm!.dateTime.subtract(Duration(minutes: (_missionSettings!.sleepGoal * 60).toInt())).difference(DateTime.now()).isNegative ? Colors.orangeAccent : Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'until bedtime',
                          style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Wake up at ${_formatTime(_nextAlarm!.dateTime)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ] else ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_formatTime(_nextAlarm!.dateTime), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 12),
                        const Text(
                          'Quick Alarm',
                          style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Time until wake: ${_formatDuration(_nextAlarm!.dateTime.difference(DateTime.now()))}',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
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
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade900, Colors.purple.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Tomorrow's Mission ♟", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text('$_userElo Elo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text("Goal: Beat 42 seconds", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("🔥 Streak: $_currentStreak days", style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sleep Readiness Checklist
                  const Text('Sleep Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      color: _isTracking ? Colors.green.shade800 : colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        if (!_isTracking) BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(_isTracking ? Icons.nights_stay : Icons.bedtime, color: Colors.white, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          _isTracking ? 'Grandmaster Wake Active' : 'Start Sleep Mode',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (_isTracking)
                           const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text("✓ Tracking active", style: TextStyle(color: Colors.white70, fontSize: 12))
                           )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                const Text('Relax Sounds', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSoundButton('🌧️', 'Rain', 'audio/rain.mp3'),
                    _buildSoundButton('🌊', 'Ocean', 'audio/ocean.mp3'),
                    _buildSoundButton('🌴', 'Jungle', 'audio/brown_noise.mp3'),
                    _buildSoundButton('🤍', 'White', 'audio/white_noise.mp3'),
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
              Icon(icon, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15)),
           ]
        )
     );
  }

  Widget _buildSoundButton(String emoji, String name, String assetPath) {
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
              color: isPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.white54, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
