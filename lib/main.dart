import 'package:flutter/cupertino.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/radar_provider.dart';
import 'package:modbus_studio/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: RadarScreen(),
    );
  }
}

class RadarScreen extends HookConsumerWidget {
  const RadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarState = ref.watch(radarProvider);
    final radarNotifier = ref.read(radarProvider.notifier);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Modbus Studio Radar'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: radarState.isScanning ? radarNotifier.stopScan : radarNotifier.startScan,
          child: radarState.isScanning 
              ? const CupertinoActivityIndicator() 
              : const Text('Scan'),
        ),
      ),
      child: SafeArea(
        child: radarState.devices.isEmpty && !radarState.isScanning
            ? const Center(child: Text('Tap Scan to start'))
            : ListView.builder(
                itemCount: radarState.devices.length,
                itemBuilder: (context, index) {
                  final device = radarState.devices[index];
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.systemGrey4,
                          width: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.ip, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('${device.status} - ${device.latencyMs}ms', style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
