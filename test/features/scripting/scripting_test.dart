import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/scripting/scripting_provider.dart';
import 'package:modbus_studio/features/scripting/scripting_screen.dart';

void main() {
  group('ScriptingNotifier Unit Tests', () {
    test('Initial state has default script and disabled engine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(scriptingProvider);
      expect(state.code, contains('Modbus.getRegister(40001)'));
      expect(state.isEnabled, isFalse);
      expect(state.logs, isEmpty);
    });

    test('setCode updates script code in state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scriptingProvider.notifier);
      const newCode = 'console.log("Hello Modbus");';

      notifier.setCode(newCode);

      final state = container.read(scriptingProvider);
      expect(state.code, newCode);
    });

    test('setEnabled updates engine state and logs action', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scriptingProvider.notifier);

      notifier.setEnabled(true);

      final state = container.read(scriptingProvider);
      expect(state.isEnabled, isTrue);
      expect(state.logs.first, contains('ENABLED'));
    });

    test('clearLogs flushes all execution logs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(scriptingProvider.notifier);
      notifier.setEnabled(true);
      notifier.clearLogs();

      final state = container.read(scriptingProvider);
      expect(state.logs, isEmpty);
    });
  });

  group('ScriptingScreen Widget Tests', () {
    testWidgets('ScriptingScreen renders editor, logs, and live toggles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CupertinoApp(
            home: ScriptingScreen(),
          ),
        ),
      );

      // Verify title headers
      expect(find.text('Scripting Console'), findsOneWidget);
      expect(find.text('Sandboxed JavaScript automation runner'), findsOneWidget);

      // Verify editor label and input field
      expect(find.text('EDITOR (JAVASCRIPT)'), findsOneWidget);
      expect(find.text('Live Run'), findsOneWidget);

      // Verify manual run connection warning
      expect(find.text('Manual run requires an active Modbus connection.'), findsOneWidget);

      // Verify empty console logs state
      expect(find.text('Console output is empty.'), findsOneWidget);
    });
  });
}
