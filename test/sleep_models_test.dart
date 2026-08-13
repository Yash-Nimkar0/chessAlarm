import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/services/sleep_service.dart';

void main() {
  group('Sleep Data Models Serialization', () {
    test('AudioEvent serialization and deserialization', () {
      final time = DateTime(2026, 8, 1, 3, 0, 0);
      final event = AudioEvent(
        time: time,
        type: 'Snoring',
        durationSeconds: 15,
        file: '/path/to/audio.aac',
        isSaved: true,
      );

      final json = event.toJson();
      
      expect(json['type'], 'Snoring');
      expect(json['durationSeconds'], 15);
      expect(json['file'], '/path/to/audio.aac');
      expect(json['isSaved'], true);
      expect(json['time'], time.toIso8601String());

      final parsed = AudioEvent.fromJson(json);

      expect(parsed.type, 'Snoring');
      expect(parsed.durationSeconds, 15);
      expect(parsed.file, '/path/to/audio.aac');
      expect(parsed.isSaved, true);
      expect(parsed.time, time);
    });

    test('AudioEvent deserialization defaults', () {
      final timeStr = DateTime(2026, 8, 1, 3, 0, 0).toIso8601String();
      final json = {
        'time': timeStr,
      };

      final parsed = AudioEvent.fromJson(json);

      expect(parsed.type, '🌙 Sleep Moment');
      expect(parsed.durationSeconds, 0);
      expect(parsed.file, '');
      expect(parsed.isSaved, false);
      expect(parsed.time.toIso8601String(), timeStr);
    });

    test('SleepSession serialization and deserialization', () {
      final startTime = DateTime(2026, 8, 1, 23, 0, 0);
      final endTime = DateTime(2026, 8, 2, 7, 0, 0);
      final audioTime = DateTime(2026, 8, 2, 3, 0, 0);
      
      final session = SleepSession(
        startTime: startTime,
        endTime: endTime,
        score: 85,
        confidence: 'High',
        totalMovementEvents: 10,
        soundActivityEvents: 5,
        additionalMoments: 2,
        wakePerformanceScore: 92,
        audioEvents: [
          AudioEvent(
            time: audioTime,
            type: 'Movement',
            durationSeconds: 5,
            file: '/path.aac',
          )
        ],
      );

      final json = session.toJson();

      expect(json['score'], 85);
      expect(json['confidence'], 'High');
      expect(json['totalMovementEvents'], 10);
      expect(json['soundActivityEvents'], 5);
      expect(json['additionalMoments'], 2);
      expect(json['wakePerformanceScore'], 92);
      expect(json['startTime'], startTime.toIso8601String());
      expect(json['endTime'], endTime.toIso8601String());
      expect((json['audioEvents'] as List).length, 1);

      final parsed = SleepSession.fromJson(json);

      expect(parsed.score, 85);
      expect(parsed.confidence, 'High');
      expect(parsed.totalMovementEvents, 10);
      expect(parsed.soundActivityEvents, 5);
      expect(parsed.additionalMoments, 2);
      expect(parsed.wakePerformanceScore, 92);
      expect(parsed.startTime, startTime);
      expect(parsed.endTime, endTime);
      expect(parsed.audioEvents.length, 1);
      expect(parsed.audioEvents.first.time, audioTime);
      expect(parsed.audioEvents.first.type, 'Movement');
    });
  });
}
