import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/inspector/widgets/write_control_card.dart';
import 'package:modbus_studio/features/inspector/widgets/historian_chart.dart';

class RegisterExplorerScreen extends HookConsumerWidget {
  const RegisterExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final libraryState = ref.watch(deviceLibraryProvider);

    // Track which register is selected for chart preview
    final selectedRegisterIndex = useState<int>(0);

    if (!connState.isConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.square_grid_3x2_fill,
                size: 64,
                color: CupertinoColors.systemGrey.withValues(alpha:0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Register Explorer Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'No active Modbus node connection. Select a device from the Connection Hub or Network Scan to start exploring registers.',
                style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () {
                  ref.read(uiProvider.notifier).setScreen(AppScreen.hub);
                },
                child: const Text('Go to Connection Hub', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final selectedAddress = 40001 + selectedRegisterIndex.value;

    return CustomScrollView(
      slivers: [
        // Polling info row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.cube_box_fill, color: CupertinoColors.systemTeal, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Holding Registers (FC 03)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CupertinoColors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C2C35), width: 0.5),
                  ),
                  child: const Text(
                    'Poll Interval: 1000ms',
                    style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey, fontFamily: 'SF Mono'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Registers grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final isSelected = selectedRegisterIndex.value == index;
                final value = index < connState.registers.length ? connState.registers[index] : 0;
                final address = 40001 + index;
                final tag = libraryState.activeTags[address];
                
                return _buildRegisterTile(
                  context,
                  index: index,
                  address: address,
                  value: value,
                  tag: tag,
                  isSelected: isSelected,
                  onTap: () {
                    selectedRegisterIndex.value = index;
                  },
                );
              },
              childCount: connState.registers.isNotEmpty ? connState.registers.length : 10,
            ),
          ),
        ),

        // Historian Chart section for selected register
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              children: [
                // Embed the historian chart with selected address
                HistorianChart(
                  ipAddress: connState.activeIp ?? '',
                  address: selectedAddress,
                ),
                
                // Embed the write panel
                WriteControlCard(
                  onWriteCoil: (addr, val) => connNotifier.writeCoil(addr, val),
                  onWriteRegister: (addr, val) => connNotifier.writeRegister(addr, val),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterTile(
    BuildContext context, {
    required int index,
    required int address,
    required int value,
    String? tag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Generate hex string representation
    final hexString = '0x${value.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? CupertinoColors.systemTeal.withValues(alpha:0.12)
              : const Color(0xFF141419).withValues(alpha:0.6),
          border: Border.all(
            color: isSelected 
                ? CupertinoColors.systemTeal 
                : CupertinoColors.systemTeal.withValues(alpha:0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tag != null ? '$address: $tag' : 'Holding Reg $address',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey2, 
                      fontSize: 12, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  hexString,
                  style: const TextStyle(
                    fontFamily: 'SF Mono',
                    color: CupertinoColors.systemGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'SF Mono',
                color: isSelected ? CupertinoColors.white : CupertinoColors.systemTeal,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0)
     .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 150.ms);
  }
}
