import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/reports/reports_screen.dart';

void main() {
  testWidgets('ReportsScreen renders offline state when disconnected', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: ReportsScreen(),
        ),
      ),
    );

    // Verify offline message exists
    expect(find.text('Reports Center Offline'), findsOneWidget);
    expect(find.text('Connect to a active Modbus TCP/Serial node to generate compliance diagnostic reports.'), findsOneWidget);
    expect(find.text('Go to Connection Hub'), findsOneWidget);
  });
}
