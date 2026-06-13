import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/features/inspector/device_inspector_screen.dart';
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
        primaryColor: CupertinoColors.systemTeal,
        scaffoldBackgroundColor: Color(0xFF0A0A0C), // Deep dark Apple style
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
        middle: const Text('Network Radar', style: TextStyle(letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF0A0A0C).withValues(alpha:0.6),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: radarState.isScanning ? radarNotifier.stopScan : radarNotifier.startScan,
          child: radarState.isScanning 
              ? const CupertinoActivityIndicator() 
              : const Text('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemTeal.withValues(alpha:0.15),
              ),
            ).animate(onPlay: (controller) => controller.repeat()).blur(end: const Offset(100, 100), duration: 2.seconds),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Radar visualizer
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: CupertinoColors.systemTeal.withValues(alpha:0.3), width: 1),
                      color: CupertinoColors.systemTeal.withValues(alpha:0.05),
                    ),
                    child: const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 48, color: CupertinoColors.systemTeal),
                  ).animate(target: radarState.isScanning ? 1 : 0)
                   .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds, curve: Curves.easeInOut)
                   .tint(color: CupertinoColors.systemTeal.withValues(alpha:0.4)),
                ),
                const SizedBox(height: 40),
                
                // Device List
                Expanded(
                  child: radarState.devices.isEmpty && !radarState.isScanning
                      ? Center(
                          child: const Text('Ready to scan for Modbus devices', style: TextStyle(color: CupertinoColors.systemGrey))
                            .animate().fadeIn(duration: 500.ms),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: radarState.devices.length,
                          itemBuilder: (context, index) {
                            final device = radarState.devices[index];
                            final isFast = device.latencyMs < 50;
                            final statusColor = isFast ? CupertinoColors.systemGreen : CupertinoColors.systemOrange;

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => DeviceInspectorScreen(ipAddress: device.ip),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C1E).withValues(alpha:0.7),
                                        border: Border.all(color: const Color(0xFF2C2C2E).withValues(alpha:0.5)),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha:0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(CupertinoIcons.device_laptop, color: statusColor, size: 20),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(device.ip, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
                                                const SizedBox(height: 4),
                                                Text(device.status, style: TextStyle(fontSize: 13, color: statusColor.withValues(alpha:0.8))),
                                              ],
                                            ),
                                          ),
                                          const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
