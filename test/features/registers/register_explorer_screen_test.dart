import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/registers/register_explorer_screen.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';
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

// Mock device library notifier
class MockDeviceLibraryNotifier extends DeviceLibraryNotifier {
  final DeviceLibraryState initialStatus;
  MockDeviceLibraryNotifier(this.initialStatus);

  @override
  DeviceLibraryState build() {
    return initialStatus;
  }
}

void main() {
  testWidgets('RegisterExplorerScreen renders offline state when disconnected', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: RegisterExplorerScreen(),
          ),
        ),
      ),
    );

    // Verify offline message elements exist
    expect(find.text('Register Explorer Offline'), findsOneWidget);
    expect(find.textContaining('No active Modbus node connection'), findsOneWidget);
    expect(find.text('Go to Connection Hub'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('RegisterExplorerScreen renders poll context and registers when connected', (tester) async {
    final mockStatus = ConnectionStatus(
      isConnected: true,
      activeIp: '192.168.1.10',
      activeConfig: const ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.10',
        port: 502,
      ),
      registers: [11, 22, 33, 44],
      functionCode: 3,
      startAddress: 0,
      quantity: 4,
    );

    final mockLibState = DeviceLibraryState(
      activeTags: {
        40001: 'Temperature',
        40002: 'Pressure',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(() => MockConnectionNotifier(mockStatus)),
          deviceLibraryProvider.overrideWith(() => MockDeviceLibraryNotifier(mockLibState)),
        ],
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            child: RegisterExplorerScreen(),
          ),
        ),
      ),
    );

    // Verify Poll Context headers exist
    expect(find.text('MODBUS POLL CONTEXT'), findsOneWidget);
    expect(find.text('FC 03: Holding Regs'), findsOneWidget);

    // Verify registers and their tags render
    expect(find.text('40001: Temperature'), findsOneWidget);
    expect(find.text('40002: Pressure'), findsOneWidget);
    expect(find.text('Reg 40003'), findsOneWidget);

    // Verify register values display correctly
    expect(find.text('11'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
