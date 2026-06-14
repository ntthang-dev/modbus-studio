// Copyright (c) 2026 ntthang-dev. All rights reserved.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/hub/connection_hub_screen.dart';
import 'package:modbus_studio/features/hub/site_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class MockSiteNotifier extends SiteNotifier {
  final List<Site> initialSites;
  final List<ConnectionProfile> initialProfiles;

  MockSiteNotifier({
    this.initialSites = const [],
    this.initialProfiles = const [],
  });

  @override
  SiteState build() {
    return SiteState(
      sites: initialSites,
      profiles: initialProfiles,
      isLoading: false,
    );
  }

  @override
  Future<void> loadAll() async {}
}

class MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionStatus initialStatus;
  MockConnectionNotifier(this.initialStatus);

  @override
  ConnectionStatus build() {
    return initialStatus;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required List<Site> sites,
    required List<ConnectionProfile> profiles,
    required ConnectionStatus connectionStatus,
    MediaQueryData mediaQueryData = const MediaQueryData(),
  }) {
    return ProviderScope(
      overrides: [
        siteProvider.overrideWith(() => MockSiteNotifier(
              initialSites: sites,
              initialProfiles: profiles,
            )),
        connectionProvider.overrideWith(() => MockConnectionNotifier(connectionStatus)),
      ],
      child: CupertinoApp(
        home: MediaQuery(
          data: mediaQueryData,
          child: const CupertinoPageScaffold(
            child: ConnectionHubScreen(),
          ),
        ),
      ),
    );
  }

  group('ConnectionHubScreen Widget Tests', () {
    testWidgets('renders System Status Header, Quick Connect Form, and Site Manager', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          sites: [const Site(id: 1, name: 'Main Office', description: 'Headquarters')],
          profiles: [],
          connectionStatus: ConnectionStatus(isConnected: false),
        ),
      );
      await tester.pumpAndSettle();

      // Verify System Status Header metrics
      expect(find.text('SYSTEM STATUS'), findsOneWidget);
      expect(find.text('Modbus Studio Workstation'), findsOneWidget);
      expect(find.text('SITES'), findsOneWidget);
      expect(find.text('PROFILES'), findsOneWidget);

      // Verify connection wizard form elements
      expect(find.text('Connection Wizard'), findsOneWidget);
      expect(find.text('IP Address'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Slave ID (Unit ID)'), findsOneWidget);

      // Verify site manager elements
      expect(find.text('Multi-Site Manager'), findsOneWidget);
      expect(find.text('All Sites'), findsOneWidget);
      expect(find.text('Main Office'), findsOneWidget);
    });

    testWidgets('toggles advanced options collapsible drawer', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          sites: [],
          profiles: [],
          connectionStatus: ConnectionStatus(isConnected: false),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, advanced settings controls are hidden
      expect(find.text('Preset Template'), findsNothing);
      expect(find.text('Import JSON'), findsNothing);
      expect(find.text('Export JSON'), findsNothing);

      // Verify the toggle button is present
      final toggleButton = find.text('Show Advanced Options');
      expect(toggleButton, findsOneWidget);

      // Tap to expand
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Advanced settings controls should now be visible
      expect(find.text('Preset Template'), findsOneWidget);
      expect(find.text('Import JSON'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);

      // Tap to collapse
      final hideButton = find.text('Hide Advanced Options');
      expect(hideButton, findsOneWidget);
      await tester.tap(hideButton);
      await tester.pumpAndSettle();

      // Advanced settings controls should be hidden again
      expect(find.text('Preset Template'), findsNothing);
      expect(find.text('Import JSON'), findsNothing);
      expect(find.text('Export JSON'), findsNothing);
    });

    testWidgets('respects disableAnimations media query', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Build with disableAnimations = true
      await tester.pumpWidget(
        buildTestWidget(
          sites: [],
          profiles: [],
          connectionStatus: ConnectionStatus(isConnected: false),
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand advanced options
      final toggleButton = find.text('Show Advanced Options');
      await tester.tap(toggleButton);
      
      // Because animations are disabled (Duration.zero), pump() immediately triggers layout updates without waiting for transitions.
      await tester.pump();

      // Advanced settings controls should be visible immediately in 0 ms
      expect(find.text('Preset Template'), findsOneWidget);
      expect(find.text('Import JSON'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
    });
  });
}
