// Copyright (c) 2026 ntthang-dev. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/reports/reports_screen.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

// Mock connection provider notifier
class MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionStatus initialStatus;
  MockConnectionNotifier(this.initialStatus);

  @override
  ConnectionStatus build() {
    return initialStatus;
  }
}

// Mock alarm provider notifier
class MockAlarmNotifier extends AlarmNotifier {
  final AlarmState initialStatus;
  MockAlarmNotifier(this.initialStatus);

  @override
  AlarmState build() {
    return initialStatus;
  }
}

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

  testWidgets('ReportsScreen renders selector options when connected', (tester) async {
    final mockStatus = ConnectionStatus(
      isConnected: true,
      activeIp: '192.168.1.10',
      activeConfig: const ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.10',
        port: 502,
      ),
      registers: [1, 2, 3],
    );

    final mockAlarmState = AlarmState(
      rules: [],
      logs: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(() => MockConnectionNotifier(mockStatus)),
          alarmProvider.overrideWith(() => MockAlarmNotifier(mockAlarmState)),
        ],
        child: const CupertinoApp(
          home: ReportsScreen(),
        ),
      ),
    );

    // Verify header and titles
    expect(find.text('Compliance & Diagnostic Reports'), findsOneWidget);
    expect(find.text('Configure range, format, and generate handover reports for active nodes.'), findsOneWidget);

    // Verify type/range headers & tiles
    expect(find.text('REPORT TYPE & RANGE'), findsOneWidget);
    expect(find.text('Current Snapshot'), findsOneWidget);
    expect(find.text('Last 24 Hours'), findsOneWidget);
    expect(find.text('Last 7 Days'), findsOneWidget);
    expect(find.text('Custom Range'), findsOneWidget);

    // Verify export format options
    expect(find.text('EXPORT FORMAT'), findsOneWidget);
    expect(find.text('PDF Report'), findsOneWidget);
    expect(find.text('CSV Export'), findsOneWidget);
  });

  testWidgets('ReportsScreen shows custom start/end time selectors when Custom Range is selected', (tester) async {
    final mockStatus = ConnectionStatus(
      isConnected: true,
      activeIp: '192.168.1.10',
      activeConfig: const ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.10',
        port: 502,
      ),
      registers: [1, 2, 3],
    );

    final mockAlarmState = AlarmState(
      rules: [],
      logs: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(() => MockConnectionNotifier(mockStatus)),
          alarmProvider.overrideWith(() => MockAlarmNotifier(mockAlarmState)),
        ],
        child: const CupertinoApp(
          home: ReportsScreen(),
        ),
      ),
    );

    // Verify date/time picker fields are not present yet
    expect(find.text('START DATETIME'), findsNothing);
    expect(find.text('END DATETIME'), findsNothing);

    // Tap "Custom Range" tile to select it
    await tester.tap(find.text('Custom Range'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify custom range input selectors are now visible
    expect(find.text('START DATETIME'), findsOneWidget);
    expect(find.text('END DATETIME'), findsOneWidget);
  });
}
