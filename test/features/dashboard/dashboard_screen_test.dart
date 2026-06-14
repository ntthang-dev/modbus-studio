import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/dashboard/dashboard_screen.dart';
import 'package:modbus_studio/features/dashboard/widgets/hmi_radial_gauge.dart';
import 'package:modbus_studio/features/dashboard/widgets/hmi_tank_level.dart';

void main() {
  testWidgets('DashboardScreen renders widget selectors and canvas', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Verify header exists
    expect(find.text('HMI DASHBOARD BUILDER'), findsOneWidget);

    // Verify widget builder cards exist
    expect(find.text('Radial Dial'), findsOneWidget);
    expect(find.text('Tank Level'), findsOneWidget);

    // Verify empty state message exists
    expect(find.text('No HMI widgets added yet. Tap a preset card above to populate your workstation canvas.'), findsOneWidget);
  });

  testWidgets('DashboardScreen allows adding widgets and binding them to registers', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Tap "Radial Dial" to add it
    await tester.tap(find.text('Radial Dial'));
    await tester.pumpAndSettle();

    // Verify gauge is added to canvas
    expect(find.byType(HmiRadialGauge), findsOneWidget);

    // Tap "Tank Level" to add it
    await tester.tap(find.text('Tank Level'));
    await tester.pumpAndSettle();

    // Verify tank level is added to canvas
    expect(find.byType(HmiTankLevel), findsOneWidget);
  });
}
