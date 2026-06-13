import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/automation/automation_screen.dart';

void main() {
  testWidgets('AutomationScreen renders header, warnings and empty state when no tasks', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: AutomationScreen(),
        ),
      ),
    );

    // Verify header exists
    expect(find.text('Automation Console'), findsOneWidget);
    expect(find.text('Scheduled write triggers (FC 05 / FC 06)'), findsOneWidget);

    // Verify Add Task button is present
    expect(find.text('Add Task'), findsOneWidget);

    // Verify warning for offline mode is displayed
    expect(find.text('Device Offline. Tasks will execute once a connection is established.'), findsOneWidget);

    // Verify empty state is displayed
    expect(find.text('No scheduled writes configured'), findsOneWidget);
    expect(find.text('Tap "Add Task" to configure periodic automated writes.'), findsOneWidget);
  });

  testWidgets('AutomationScreen opens Add Task modal sheet and permits entering details', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: AutomationScreen(),
        ),
      ),
    );

    // Open add task modal
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.text('Configure Scheduled Write'), findsOneWidget);
    expect(find.text('Write Target Type'), findsOneWidget);
    expect(find.text('Modbus Address'), findsOneWidget);
    expect(find.text('Value to Write'), findsOneWidget);
    expect(find.text('Trigger Interval (Seconds)'), findsOneWidget);

    // Close modal
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    // Verify modal is dismissed
    expect(find.text('Configure Scheduled Write'), findsNothing);
  });
}
