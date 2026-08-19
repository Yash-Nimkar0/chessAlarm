import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class AudioEvent {
  final DateTime time;
  final String type;
  final int durationSeconds;
  final String file;
  bool isSaved;

  AudioEvent({
    required this.time,
    required this.type,
    required this.durationSeconds,
    required this.file,
    this.isSaved = false,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'type': type,
        'durationSeconds': durationSeconds,
        'file': file,
        'isSaved': isSaved,
      };

  factory AudioEvent.fromJson(Map<String, dynamic> json) => AudioEvent(
        time: DateTime.parse(json['time']),
        type: json['type'] ?? '🌙 Sleep Moment',
        durationSeconds: json['durationSeconds'] ?? 0,
        file: json['file'] ?? '',
        isSaved: json['isSaved'] ?? false,
      );
}

class SleepSession {
  final DateTime startTime;
  final DateTime endTime;
  final int score;
  final String confidence;
  final int totalMovementEvents;
  final int soundActivityEvents;
  final int additionalMoments;
  final int? wakePerformanceScore;
  final List<AudioEvent> audioEvents;

  SleepSession({
    required this.startTime,
    required this.endTime,
    required this.score,
    required this.confidence,
    required this.totalMovementEvents,
    required this.soundActivityEvents,
    this.additionalMoments = 0,
    this.wakePerformanceScore,
    this.audioEvents = const [],
  });

  Duration get duration => endTime.difference(startTime);

  SleepSession copyWith({
    int? score,
    String? confidence,
    int? wakePerformanceScore,
    int? additionalMoments,
    List<AudioEvent>? audioEvents,
  }) {
    return SleepSession(
      startTime: startTime,
      endTime: endTime,
      score: score ?? this.score,
      confidence: confidence ?? this.confidence,
      totalMovementEvents: totalMovementEvents,
      soundActivityEvents: soundActivityEvents,
      additionalMoments: additionalMoments ?? this.additionalMoments,
      wakePerformanceScore: wakePerformanceScore ?? this.wakePerformanceScore,
      audioEvents: audioEvents ?? this.audioEvents,
    );
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'score': score,
        'confidence': confidence,
        'totalMovementEvents': totalMovementEvents,
        'soundActivityEvents': soundActivityEvents,
        'additionalMoments': additionalMoments,
        'wakePerformanceScore': wakePerformanceScore,
        'audioEvents': audioEvents.map((e) => e.toJson()).toList(),
      };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        score: json['score'] ?? 80,
        confidence: json['confidence'] ?? 'Medium',
        totalMovementEvents: json['totalMovementEvents'] ?? 0,
        soundActivityEvents: json['soundActivityEvents'] ?? json['totalNoiseEvents'] ?? 0,
        additionalMoments: json['additionalMoments'] ?? 0,
        wakePerformanceScore: json['wakePerformanceScore'],
        audioEvents: (json['audioEvents'] as List<dynamic>?)
                ?.map((e) => AudioEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SleepTaskHandler());
}

class SleepTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class SleepService {
  static const String _historyKey = 'sleep_history';
  static const String _checkpointKey = 'sleep_checkpoint';
  
  static bool _isTracking = false;
  static final AudioPlayer _silentPlayer = AudioPlayer();
  static DateTime? _startTime;
  static int _movementEvents = 0;
  static int _soundEvents = 0;
  static int _additionalMoments = 0;
  static List<AudioEvent> _currentAudioEvents = [];

  static StreamSubscription<AccelerometerEvent>? _accelSub;
  static StreamSubscription<NoiseReading>? _noiseSub;
  static NoiseMeter? _noiseMeter;
  static AudioRecorder? _audioRecorder;
  static StreamSubscription? _audioStreamSub;
  
  static DateTime? _lastMovementTime;
  static DateTime? _lastSoundTime;
  static Timer? _checkpointTimer;
  
  static final List<Uint8List> _pcmBuffer = [];
  static bool _isRecordingToDisk = false;
  static DateTime? _recordingStartTime;
  static DateTime? _soundSpikeStartTime;

  static bool get isTracking => _isTracking;

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sleep_tracking',
        channelName: 'Sleep Tracking',
        channelDescription: 'Keeps sleep tracking alive in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
        stopWithTask: false,
      ),
    );
  }

  static Future<void> _saveCheckpoint() async {
    if (!_isTracking || _startTime == null) return;
    final prefs = await SharedPreferences.getInstance();
    final session = SleepSession(
      startTime: _startTime!,
      endTime: DateTime.now(),
      score: 0,
      confidence: 'Active',
      totalMovementEvents: _movementEvents,
      soundActivityEvents: _soundEvents,
      additionalMoments: _additionalMoments,
      audioEvents: _currentAudioEvents,
    );
    await prefs.setString(_checkpointKey, jsonEncode(session.toJson()));
  }

  static Future<void> startTracking() async {
    if (_isTracking) return;
    
    _initForegroundTask();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Wakely Sleep Tracking',
        notificationText: 'Tracking your sleep...',
        callback: startCallback,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final privacyMode = prefs.getInt('privacy_mode') ?? 2; // 0=Off, 1=Detect, 2=Save Moments

    if (privacyMode > 0) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (kDebugMode) print("Microphone permission denied for sleep tracking.");
      } else {
        try {
          _noiseMeter = NoiseMeter();
          _noiseSub = _noiseMeter!.noise.listen(_onNoiseReading, onError: (e) {
            if (kDebugMode) print(e);
          });
          
          if (privacyMode == 2) {
             await _startAudioBuffer();
          }
        } catch (e) {
          if (kDebugMode) print("Failed to init noise meter/audio: $e");
        }
      }
    }

    _isTracking = true;
    _startTime = DateTime.now();
    _movementEvents = 0;
    _soundEvents = 0;
    _additionalMoments = 0;
    _currentAudioEvents = [];
    _lastMovementTime = null;
    _lastSoundTime = null;
    _pcmBuffer.clear();

    _checkpointTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _saveCheckpoint();
    });

    double movementThreshold = 0.5; // Euclidean deviation
    _accelSub = accelerometerEventStream().listen((event) {
      double magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      if ((magnitude - 9.8).abs() > movementThreshold) {
        final now = DateTime.now();
        if (_lastMovementTime == null || now.difference(_lastMovementTime!).inSeconds > 30) {
          _movementEvents++;
          _lastMovementTime = now;
        }
      }
    });
    
    _silentPlayer.setReleaseMode(ReleaseMode.loop);
    _silentPlayer.play(AssetSource('silent.mp3'), volume: 0.0);
  }
  
  static Future<void> _startAudioBuffer() async {
    _audioRecorder = AudioRecorder();
    if (await _audioRecorder!.hasPermission()) {
      final stream = await _audioRecorder!.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      _audioStreamSub = stream.listen((data) {
         _pcmBuffer.add(data);
         // 16000 hz * 2 bytes * 1 channel = 32000 bytes per second
         // Limit buffer to roughly 10 seconds of audio -> ~320,000 bytes
         int currentSize = _pcmBuffer.fold(0, (sum, chunk) => sum + chunk.length);
         while (currentSize > 320000 && _pcmBuffer.isNotEmpty) {
           currentSize -= _pcmBuffer.first.length;
           _pcmBuffer.removeAt(0);
         }
         
         if (_isRecordingToDisk && _recordingStartTime != null) {
            final now = DateTime.now();
            if (now.difference(_recordingStartTime!).inSeconds > 15) {
               _saveBufferToClip();
            }
         }
      });
    }
  }
  
  static void _onNoiseReading(NoiseReading noiseReading) {
      if (noiseReading.meanDecibel > 60.0) {
        final now = DateTime.now();
        if (_lastSoundTime == null || now.difference(_lastSoundTime!).inMinutes > 2) {
          if (_soundSpikeStartTime == null) {
            _soundSpikeStartTime = now;
          } else {
             // 2 seconds continuous spike
             if (now.difference(_soundSpikeStartTime!).inSeconds >= 2) {
                 _soundEvents++;
                 _lastSoundTime = now;
                 _soundSpikeStartTime = null;
                 
                 // Trigger audio save if enabled
                 if (_audioRecorder != null && !_isRecordingToDisk) {
                    if (_currentAudioEvents.length < 10) {
                       _isRecordingToDisk = true;
                       _recordingStartTime = now;
                    } else {
                       _additionalMoments++;
                    }
                 }
             }
          }
        }
      } else {
         _soundSpikeStartTime = null;
      }
  }
  
  static Future<void> _saveBufferToClip() async {
      _isRecordingToDisk = false;
      if (_pcmBuffer.isEmpty) return;
      
      try {
        final dir = await getApplicationDocumentsDirectory();
        final clipDir = Directory('${dir.path}/sleep_audio');
        if (!await clipDir.exists()) await clipDir.create();
        
        final fileName = 'sleep_${DateTime.now().millisecondsSinceEpoch}.wav';
        final file = File('${clipDir.path}/$fileName');
        
        // Write WAV
        int totalAudioLen = _pcmBuffer.fold(0, (len, chunk) => len + chunk.length);
        int totalDataLen = totalAudioLen + 36;
        int longSampleRate = 16000;
        int channels = 1;
        int byteRate = 16000 * 2 * 1;
        
        var header = Uint8List(44);
        header[0] = 82; header[1] = 73; header[2] = 70; header[3] = 70; 
        header[4] = (totalDataLen & 0xff); header[5] = ((totalDataLen >> 8) & 0xff); header[6] = ((totalDataLen >> 16) & 0xff); header[7] = ((totalDataLen >> 24) & 0xff);
        header[8] = 87; header[9] = 65; header[10] = 86; header[11] = 69; 
        header[12] = 102; header[13] = 109; header[14] = 116; header[15] = 32; 
        header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0; 
        header[20] = 1; header[21] = 0; header[22] = channels; header[23] = 0; 
        header[24] = (longSampleRate & 0xff); header[25] = ((longSampleRate >> 8) & 0xff); header[26] = ((longSampleRate >> 16) & 0xff); header[27] = ((longSampleRate >> 24) & 0xff);
        header[28] = (byteRate & 0xff); header[29] = ((byteRate >> 8) & 0xff); header[30] = ((byteRate >> 16) & 0xff); header[31] = ((byteRate >> 24) & 0xff);
        header[32] = (2 * channels); header[33] = 0; header[34] = 16; header[35] = 0; 
        header[36] = 100; header[37] = 97; header[38] = 116; header[39] = 97; 
        header[40] = (totalAudioLen & 0xff); header[41] = ((totalAudioLen >> 8) & 0xff); header[42] = ((totalAudioLen >> 16) & 0xff); header[43] = ((totalAudioLen >> 24) & 0xff);
        
        final sink = file.openWrite();
        sink.add(header);
        for (var chunk in _pcmBuffer) {
           sink.add(chunk);
        }
        await sink.close();
        
        _currentAudioEvents.add(AudioEvent(
           time: DateTime.now(),
           type: "🌙 Sleep Moment",
           durationSeconds: 25,
           file: file.path,
        ));
      } catch (e) {
         if (kDebugMode) print("Failed to save clip: $e");
      }
  }

  static Future<SleepSession?> stopTracking() async {
    if (!_isTracking || _startTime == null) return null;

    _accelSub?.cancel();
    _noiseSub?.cancel();
    _audioStreamSub?.cancel();
    _audioRecorder?.dispose();
    _audioRecorder = null;
    _silentPlayer.stop();
    _checkpointTimer?.cancel();
    FlutterForegroundTask.stopService();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checkpointKey);
    
    _isTracking = false;

    final endTime = DateTime.now();
    final durationHours = endTime.difference(_startTime!).inMinutes / 60.0;
    
    // Duration (50%)
    int score = 50;
    if (durationHours < 7.5) score -= ((7.5 - durationHours) * 6).toInt();
    
    // Consistency (25%)
    int consistency = 25;
    List<SleepSession> history = await getHistory();
    if (history.isNotEmpty) {
       final last = history.last;
       int todayMins = _startTime!.hour * 60 + _startTime!.minute;
       int lastMins = last.startTime.hour * 60 + last.startTime.minute;
       int timeDiff = (todayMins - lastMins).abs();
       if (timeDiff > 720) timeDiff = 1440 - timeDiff;
       if (timeDiff > 60) {
          consistency -= (timeDiff / 30).clamp(0, 25).toInt();
       }
    }
    score += consistency;
    
    // Disturbance (5%)
    int disturbance = 5;
    double movementsPerHour = durationHours > 0 ? (_movementEvents / durationHours) : 0;
    disturbance -= (movementsPerHour * 0.5).toInt();
    disturbance -= (_soundEvents).toInt();
    score += disturbance.clamp(0, 5);

    // Confidence
    String confidence = 'High';
    if (durationHours < 3) {
      confidence = 'Low';
    } else if (_movementEvents > 30) {
      confidence = 'Medium';
    }
    
    final session = SleepSession(
      startTime: _startTime!,
      endTime: endTime,
      score: score.clamp(0, 80), // Max 80 before morning performance
      confidence: confidence,
      totalMovementEvents: _movementEvents,
      soundActivityEvents: _soundEvents,
      additionalMoments: _additionalMoments,
      audioEvents: _currentAudioEvents,
    );

    await _saveSession(session);
    return session;
  }
  
  static Future<void> recordWakePerformance(int solveTimeSec, int hintsRemaining, bool isSkip) async {
    List<SleepSession> history = await getHistory();
    if (history.isEmpty) return;
    
    SleepSession lastSession = history.last;
    if (DateTime.now().difference(lastSession.endTime).inHours < 1 && lastSession.wakePerformanceScore == null) {
      int wakeBonus = 0;
      if (!isSkip) {
        wakeBonus += 10;
        
        if (hintsRemaining == 3) {
          wakeBonus += 5;
        } else if (hintsRemaining == 2) {
          wakeBonus += 3;
        } else if (hintsRemaining == 1) {
          wakeBonus += 1;
        }
        
        // Compare with personal average
        final prefs = await SharedPreferences.getInstance();
        int personalFastest = prefs.getInt('fastest_solve_sec') ?? 999;
        // If solved within +10 seconds of fastest, give +5
        if (solveTimeSec <= personalFastest + 10) {
           wakeBonus += 5;
        } else if (solveTimeSec <= personalFastest + 30) {
           wakeBonus += 2;
        }
      }
      
      final updatedSession = lastSession.copyWith(
        score: min(100, lastSession.score + wakeBonus),
        wakePerformanceScore: wakeBonus,
      );
      
      history[history.length - 1] = updatedSession;
      final prefs = await SharedPreferences.getInstance();
      final List<String> jsonList = history.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
    }
  }
  
  static Future<void> toggleSavedState(DateTime sessionStart, String clipPath) async {
      List<SleepSession> history = await getHistory();
      for (int i = 0; i < history.length; i++) {
         if (history[i].startTime == sessionStart) {
            for (var event in history[i].audioEvents) {
               if (event.file == clipPath) {
                  event.isSaved = !event.isSaved;
               }
            }
         }
      }
      final prefs = await SharedPreferences.getInstance();
      final List<String> jsonList = history.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
  }

  static Future<void> deleteAudioEvent(DateTime sessionStart, String clipPath) async {
      List<SleepSession> history = await getHistory();
      for (int i = 0; i < history.length; i++) {
         if (history[i].startTime == sessionStart) {
            history[i].audioEvents.removeWhere((event) => event.file == clipPath);
         }
      }
      try {
         final file = File(clipPath);
         if (file.existsSync()) {
            file.deleteSync();
         }
      } catch (e) {
         if (kDebugMode) print("Failed to delete clip: $e");
      }
      final prefs = await SharedPreferences.getInstance();
      final List<String> jsonList = history.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
  }

  static Future<void> deleteAllAudioEvents() async {
      List<SleepSession> history = await getHistory();
      for (int i = 0; i < history.length; i++) {
         history[i].audioEvents.clear();
      }
      try {
         final dir = await getApplicationDocumentsDirectory();
         final clipDir = Directory('${dir.path}/sleep_audio');
         if (await clipDir.exists()) {
             clipDir.deleteSync(recursive: true);
         }
      } catch (e) {
         if (kDebugMode) print("Failed to delete all clips: $e");
      }
      final prefs = await SharedPreferences.getInstance();
      final List<String> jsonList = history.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
  }

  static Future<SleepSession> _saveSession(SleepSession session) async {
    final prefs = await SharedPreferences.getInstance();
    List<SleepSession> history = await getHistory();
    
    history.add(session);
    await prefs.setStringList(_historyKey, history.map((s) => jsonEncode(s.toJson())).toList());

    return session;
  }
  
  static Future<void> recoverOrphanedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final checkpointJson = prefs.getString(_checkpointKey);
    if (checkpointJson == null) return;
    
    try {
      final sessionData = jsonDecode(checkpointJson);
      SleepSession session = SleepSession.fromJson(sessionData);
      
      final durationHours = session.duration.inMinutes / 60.0;
      
      int score = 50;
      if (durationHours < 7.5) score -= ((7.5 - durationHours) * 6).toInt();
      
      int consistency = 25;
      List<SleepSession> history = await getHistory();
      if (history.isNotEmpty) {
         final last = history.last;
         int todayMins = session.startTime.hour * 60 + session.startTime.minute;
         int lastMins = last.startTime.hour * 60 + last.startTime.minute;
         int timeDiff = (todayMins - lastMins).abs();
         if (timeDiff > 720) timeDiff = 1440 - timeDiff;
         if (timeDiff > 60) {
            consistency -= (timeDiff / 30).clamp(0, 25).toInt();
         }
      }
      score += consistency;
      
      int disturbance = 5;
      double movementsPerHour = durationHours > 0 ? (session.totalMovementEvents / durationHours) : 0;
      disturbance -= (movementsPerHour * 0.5).toInt();
      disturbance -= (session.soundActivityEvents).toInt();
      score += disturbance.clamp(0, 5);

      String confidence = 'High';
      if (durationHours < 3) {
        confidence = 'Low';
      } else if (session.totalMovementEvents > 30) {
        confidence = 'Medium';
      }
      
      session = session.copyWith(
        score: score.clamp(0, 80),
        confidence: confidence,
      );
      
      history.add(session);
      await prefs.setStringList(_historyKey, history.map((s) => jsonEncode(s.toJson())).toList());
      await prefs.remove(_checkpointKey);
      
    } catch (e) {
      if (kDebugMode) print('Failed to recover orphaned session: $e');
      await prefs.remove(_checkpointKey);
    }
  }

  static Future<List<SleepSession>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_historyKey);
    if (jsonList == null) return [];

    // One unparseable entry (a corrupt write, a future schema change) used
    // to take down the whole history — every screen that shows sleep data
    // would hang on its loading spinner forever, since none of them expect
    // this call to ever throw. Skip just the bad entry instead.
    final sessions = <SleepSession>[];
    for (final str in jsonList) {
      try {
        sessions.add(SleepSession.fromJson(jsonDecode(str)));
      } catch (e) {
        if (kDebugMode) print('Skipping corrupt sleep history entry: $e');
      }
    }
    return sessions;
  }
  
  static Future<void> cleanupOldClips() async {
     try {
        final dir = await getApplicationDocumentsDirectory();
        final clipDir = Directory('${dir.path}/sleep_audio');
        if (!await clipDir.exists()) return;
        
        final files = clipDir.listSync().whereType<File>().toList();
        int totalSize = 0;
        for (var file in files) {
           totalSize += file.lengthSync();
        }
        
        if (totalSize > 500 * 1024 * 1024) {
           files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
           for (var file in files) {
              bool isSaved = await _isFileSaved(file.path);
              if (!isSaved) {
                 file.deleteSync();
                 totalSize -= file.lengthSync();
                 if (totalSize < 400 * 1024 * 1024) break;
              }
           }
        }
        
        final now = DateTime.now();
        for (var file in files) {
           if (now.difference(file.lastModifiedSync()).inDays > 30) {
              bool isSaved = await _isFileSaved(file.path);
              if (!isSaved) {
                 file.deleteSync();
              }
           }
        }
     } catch (e) {
        if (kDebugMode) print("Cleanup failed: $e");
     }
  }
  
  static Future<bool> _isFileSaved(String path) async {
      final history = await getHistory();
      for (var session in history) {
         for (var event in session.audioEvents) {
            if (event.file == path && event.isSaved) return true;
         }
      }
      return false;
  }
}
