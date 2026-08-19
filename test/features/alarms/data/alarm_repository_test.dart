import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/data/alarm_repository.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlarmRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = AlarmRepository();
  });

  WakelyAlarm createAlarm(int id) {
    final now = DateTime.now();
    return WakelyAlarm(
      id: id,
      time: now,
      enabled: true,
      type: AlarmType.standard,
      recurrence: Recurrence.none(),
      createdAt: now,
      updatedAt: now,
    );
  }

  group('AlarmRepository', () {
    test('getAll returns empty list initially', () async {
      final alarms = await repository.getAll();
      expect(alarms, isEmpty);
      expect(await repository.isEmpty, isTrue);
    });

    test('save adds a new alarm', () async {
      final alarm = createAlarm(1);
      await repository.save(alarm);

      final alarms = await repository.getAll();
      expect(alarms, hasLength(1));
      expect(alarms.first.id, 1);
    });

    test('save updates existing alarm', () async {
      final alarm = createAlarm(1);
      await repository.save(alarm);

      final updatedAlarm = alarm.copyWith(label: 'Updated Label');
      await repository.save(updatedAlarm);

      final alarms = await repository.getAll();
      expect(alarms, hasLength(1));
      expect(alarms.first.label, 'Updated Label');
    });

    test('getById returns correct alarm', () async {
      await repository.save(createAlarm(1));
      await repository.save(createAlarm(2));

      final alarm = await repository.getById(2);
      expect(alarm, isNotNull);
      expect(alarm!.id, 2);

      final missing = await repository.getById(99);
      expect(missing, isNull);
    });

    test('delete removes alarm and returns true', () async {
      await repository.save(createAlarm(1));
      
      final result = await repository.delete(1);
      expect(result, isTrue);
      
      final alarms = await repository.getAll();
      expect(alarms, isEmpty);
    });

    test('delete returns false if alarm does not exist', () async {
      await repository.save(createAlarm(1));
      
      final result = await repository.delete(99);
      expect(result, isFalse);
      
      final alarms = await repository.getAll();
      expect(alarms, hasLength(1));
    });
  });
}
