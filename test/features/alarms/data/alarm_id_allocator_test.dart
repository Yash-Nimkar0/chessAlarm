import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/data/alarm_id_allocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlarmIdAllocator', () {
    test('allocates monotonically', () async {
      final id1 = await AlarmIdAllocator.allocate();
      final id2 = await AlarmIdAllocator.allocate();
      final id3 = await AlarmIdAllocator.allocate();

      expect(id1, 1);
      expect(id2, 2);
      expect(id3, 3);
    });

    test('survives restart (mocked via reading existing value)', () async {
      SharedPreferences.setMockInitialValues({'wakely_next_alarm_id': 42});
      
      final id1 = await AlarmIdAllocator.allocate();
      final id2 = await AlarmIdAllocator.allocate();

      expect(id1, 42);
      expect(id2, 43);
    });

    test('ensureAbove advances allocator past existing IDs', () async {
      SharedPreferences.setMockInitialValues({'wakely_next_alarm_id': 5});
      
      await AlarmIdAllocator.ensureAbove(10);
      
      final nextId = await AlarmIdAllocator.allocate();
      expect(nextId, 11);
    });

    test('ensureAbove does not decrease allocator', () async {
      SharedPreferences.setMockInitialValues({'wakely_next_alarm_id': 20});
      
      await AlarmIdAllocator.ensureAbove(10);
      
      final nextId = await AlarmIdAllocator.allocate();
      expect(nextId, 20); // Remained at 20, so allocation returns 20
    });

    test('concurrent allocation produces unique IDs', () async {
      // Start 5 allocations at the exact same time
      final futures = List.generate(5, (_) => AlarmIdAllocator.allocate());
      final ids = await Future.wait(futures);
      
      // All IDs should be unique
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, 5);
      
      // Values should be 1 through 5 (though order in the list might vary)
      expect(uniqueIds.containsAll([1, 2, 3, 4, 5]), isTrue);
    });
  });
}
