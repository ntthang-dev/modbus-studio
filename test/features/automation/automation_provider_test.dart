import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/automation/automation_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

void main() {
  group('AutomationNotifier Unit Tests', () {
    test('Initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(automationProvider);
      expect(state.scheduledWrites, isEmpty);
      expect(state.logs, isEmpty);
    });

    test('logs list acts as a rolling buffer capped at 100 entries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(automationProvider.notifier);

      for (int i = 0; i < 110; i++) {
        notifier.deleteScheduledWrite(i);
      }

      final state = container.read(automationProvider);
      expect(state.logs.length, equals(100));
    });

    test('clearLogs flushes all active records', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(automationProvider.notifier);
      notifier.deleteScheduledWrite(999);
      
      var state = container.read(automationProvider);
      expect(state.logs, isNotEmpty);

      notifier.clearLogs();
      state = container.read(automationProvider);
      expect(state.logs, isEmpty);
    });
  });
}
