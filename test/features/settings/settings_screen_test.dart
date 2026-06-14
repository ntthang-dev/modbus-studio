import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/settings/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen renders visual section tiles and values', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Verify sections headers and tiles
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('ENVIRONMENT & VISUALS'), findsOneWidget);
    expect(find.text('Outdoor Field Mode'), findsOneWidget);
    expect(find.text('Right Details Inspector'), findsOneWidget);

    expect(find.text('MODBUS DEFAULT TIMEOUTS'), findsOneWidget);
    expect(find.text('Response Timeout'), findsOneWidget);
    expect(find.text('Retry Count'), findsOneWidget);

    expect(find.text('DATABASE STORAGE & HYGIENE'), findsOneWidget);
    expect(find.text('Max Log Capping Limit'), findsOneWidget);
    expect(find.text('1000 rows'), findsOneWidget);

    expect(find.text('SECURITY & SAFETY'), findsOneWidget);
    expect(find.text('Write Protection'), findsOneWidget);

    expect(find.text('SYSTEM INFO'), findsOneWidget);
    expect(find.text('Modbus Studio Engine'), findsOneWidget);
  });
}
