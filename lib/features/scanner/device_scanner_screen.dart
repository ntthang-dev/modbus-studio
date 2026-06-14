import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/hooks.dart';
import 'package:flutter/services.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/radar_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class DeviceScannerScreen extends HookConsumerWidget {
  const DeviceScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarState = ref.watch(radarProvider);
    final radarNotifier = ref.read(radarProvider.notifier);
    final uiNotifier = ref.read(uiProvider.notifier);
    final connNotifier = ref.read(connectionProvider.notifier);
    
    final subnetController = useTextEditingController(text: '192.168.1');
    final portController = useTextEditingController(text: '502');

    return CustomScrollView(
      slivers: [
        // Scanner Header / Controls
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141419).withValues(alpha:0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF23232C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemTeal.withValues(alpha:0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.antenna_radiowaves_left_right,
                          color: CupertinoColors.systemTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Network Radar Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Scan Modbus TCP Port 502 targets in your subnet', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Subnet Prefix or Target IP', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: subnetController,
                              placeholder: '192.168.1 or 127.0.0.1',
                              style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono'),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E24),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2C2C35)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Port', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: portController,
                              placeholder: '502',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono'),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E24),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2C2C35)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          const Text('', style: TextStyle(fontSize: 12)), // Spacer for alignment
                          const SizedBox(height: 6),
                          CupertinoButton(
                            color: radarState.isScanning ? CupertinoColors.destructiveRed : CupertinoColors.systemTeal,
                            onPressed: () {
                              if (radarState.isScanning) {
                                radarNotifier.stopScan();
                              } else {
                                final prefix = subnetController.text.trim();
                                final portVal = int.tryParse(portController.text) ?? 502;
                                if (prefix.isNotEmpty) {
                                  radarNotifier.startScan(target: prefix, port: portVal);
                                }
                              }
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            child: radarState.isScanning
                                ? const CupertinoActivityIndicator()
                                : Text(radarState.isScanning ? 'Stop' : 'Start Radar', style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 350.ms),
        ),

        // Scanned Device Cards list header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DISCOVERED NODES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2, letterSpacing: 1.0),
                ),
                if (radarState.isScanning)
                  const Text(
                    'Sweeping subnet...',
                    style: TextStyle(fontSize: 11, color: CupertinoColors.systemYellow, fontWeight: FontWeight.w600),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds)
                else
                  Text(
                    '${radarState.devices.length} devices found',
                    style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                  ),
              ],
            ),
          ),
        ),

        // Device List Cards
        if (radarState.devices.isEmpty && !radarState.isScanning)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.circle_grid_hex_fill, size: 48, color: CupertinoColors.systemGrey.withValues(alpha:0.3)),
                    const SizedBox(height: 16),
                    const Text('No scan results available', style: TextStyle(color: CupertinoColors.systemGrey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Click "Start Radar" to sweep the local subnet for Modbus TCP devices.', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final device = radarState.devices[index];
                  final isFast = device.latencyMs < 50;
                  final statusColor = isFast ? CupertinoColors.systemGreen : CupertinoColors.systemOrange;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141419).withValues(alpha:0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF23232C)),
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
                                Text('${device.ip}:${device.port} (ID ${device.slaveId})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: CupertinoColors.white, fontFamily: 'SF Mono')),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${device.status} · ${device.latencyMs}ms',
                                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            color: CupertinoColors.systemTeal.withValues(alpha:0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () async {
                              radarNotifier.stopScan();
                              await connNotifier.connect(
                                ConnectionConfig(
                                  protocolType: 'TCP',
                                  ip: device.ip,
                                  port: device.port,
                                ),
                                slaveId: device.slaveId,
                              );
                              if (ref.read(connectionProvider).isConnected) {
                                uiNotifier.setScreen(AppScreen.registers);
                              }
                            },
                            child: const Text('Connect', style: TextStyle(color: CupertinoColors.systemTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                },
                childCount: radarState.devices.length,
              ),
            ),
          ),
      ],
    );
  }
}
