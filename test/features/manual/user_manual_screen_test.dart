// Copyright (c) 2026 ntthang-dev. All rights reserved.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/manual/user_manual_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget() {
    return const ProviderScope(
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: UserManualScreen(),
        ),
      ),
    );
  }

  group('UserManualScreen Widget Tests', () {
    testWidgets('renders Getting Started content by default in desktop split view', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check submenu headers
      expect(find.text('Getting Started'), findsAtLeastNWidgets(2)); // Title and menu item
      expect(find.text('Modbus Basics'), findsOneWidget);
      expect(find.text('Scripting Engine'), findsOneWidget);
      expect(find.text('Changelog'), findsOneWidget);
      expect(find.text('Copyright & License'), findsOneWidget);

      // Check default page content
      expect(find.textContaining('Welcome to Modbus Studio.'), findsOneWidget);
      expect(find.text('Create a Connection Profile'), findsOneWidget);
    });

    testWidgets('navigates to Modbus Basics and renders basics info cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Modbus Basics in the sidebar
      await tester.tap(find.text('Modbus Basics'));
      await tester.pumpAndSettle();

      // Check screen contents changed
      expect(find.text('Modbus Protocol Overview'), findsOneWidget);
      expect(find.textContaining('Modbus RTU (Serial)'), findsOneWidget);
      expect(find.textContaining('Modbus TCP (Ethernet)'), findsOneWidget);
      expect(find.textContaining('CRC Error Detection'), findsOneWidget);
      expect(find.textContaining('MBAP Header'), findsOneWidget);
      expect(find.textContaining('Coils (FC01)'), findsOneWidget);
    });

    testWidgets('navigates to Scripting Engine and renders code block', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Scripting Engine in the sidebar
      await tester.tap(find.text('Scripting Engine'));
      await tester.pumpAndSettle();

      // Check screen contents changed
      expect(find.text('Embedded Scripting Engine'), findsOneWidget);
      expect(find.textContaining('Available Global Methods:'), findsOneWidget);
    });

    testWidgets('navigates to Copyright & License and displays attribution', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Copyright & License in the sidebar
      await tester.tap(find.text('Copyright & License'));
      await tester.pumpAndSettle();

      // Check screen contents changed
      expect(find.text('Copyright & Licensing'), findsOneWidget);
      expect(find.textContaining('ntthang-dev (ぞたの)'), findsNWidgets(2));
      expect(find.textContaining('THE SOFTWARE IS PROVIDED "AS IS"'), findsOneWidget);
    });
  });
}
