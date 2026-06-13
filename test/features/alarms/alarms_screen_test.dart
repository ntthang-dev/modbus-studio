import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/alarms/alarms_screen.dart';

void main() {
  testWidgets('AlarmsScreen renders title, active rules and logs empty states', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: AlarmsScreen(),
        ),
      ),
    );

    // Verify header title exists
    expect(find.text('Alarms Console'), findsOneWidget);

    // Verify buttons exist
    expect(find.text('Add Rule'), findsOneWidget);
    expect(find.text('Clear Logs'), findsOneWidget);

    // Verify empty state placeholders exist
    expect(find.text('No active alarm rules'), findsOneWidget);
    expect(find.text('Alarm log is empty'), findsOneWidget);
  });

  testWidgets('AlarmsScreen opens configure alarm rule dialog', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: AlarmsScreen(),
        ),
      ),
    );

    // Tap "Add Rule" button
    await tester.tap(find.text('Add Rule'));
    await tester.pumpAndSettle();

    // Verify rule configuration form is displayed
    expect(find.text('Configure Alarm Rule'), findsOneWidget);
    expect(find.text('Rule Tag / Name'), findsOneWidget);
    expect(find.text('Modbus Address'), findsOneWidget);
    expect(find.text('Trigger Threshold'), findsOneWidget);
    expect(find.text('Trigger Condition'), findsOneWidget);
    expect(find.text('Alarm Severity'), findsOneWidget);
    expect(find.text('Save Rule'), findsOneWidget);

    // Verify cancel button works
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Configure Alarm Rule'), findsNothing);
  });
}
