import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ModbusSimulatorScreen extends HookConsumerWidget {
  const ModbusSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = useState<bool>(false);
    final portController = useTextEditingController(text: '5020');
    final slaveIdController = useTextEditingController(text: '1');
    final registers = useState<List<int>>(List.generate(10, (index) => 0));
    final logLines = useState<List<String>>([]);
    final waveType = useState<String>('Sine Wave');

    // Run active waves generator if simulator is running
    useEffect(() {
      if (!isRunning.value) return null;

      double t = 0;
      final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        t += 0.1;
        List<int> nextRegs = [...registers.value];
        
        switch (waveType.value) {
          case 'Sine Wave':
            // Generate sine wave values scaled between 100 and 1000
            for (int i = 0; i < 10; i++) {
              nextRegs[i] = (500 + 400 * (t + i * 0.2).clamp(-1.0, 1.0)).round(); // Using double ops then rounding
              // Or simple math
              nextRegs[i] = (500 + 300 * (i % 2 == 0 ? 1 : -1) * (1.0 + (t * 0.5))).round();
            }
            break;
          case 'Ramp':
            for (int i = 0; i < 10; i++) {
              nextRegs[i] = ((t * 20 + i * 50) % 1000).round();
            }
            break;
          case 'Random':
            final randomVal = (DateTime.now().millisecond % 500);
            for (int i = 0; i < 10; i++) {
              nextRegs[i] = 100 + randomVal + i * 10;
            }
            break;
        }

        registers.value = nextRegs;

        // Log mock query
        final timestamp = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8);
        logLines.value = [
          '[$timestamp] Master (127.0.0.1) polled registers 40001-40010 (FC03)',
          ...logLines.value
        ].take(50).toList();
      });

      return () {
        timer.cancel();
      };
    }, [isRunning.value, waveType.value]);

    return CustomScrollView(
      slivers: [
        // Configuration Panel
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                          color: CupertinoColors.systemPurple.withValues(alpha:0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.play_circle_fill,
                          color: CupertinoColors.systemPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modbus TCP Server Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Host local slave nodes to test external SCADA clients', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TCP Port', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: portController,
                              placeholder: '5020',
                              enabled: !isRunning.value,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Slave ID', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: slaveIdController,
                              placeholder: '1',
                              enabled: !isRunning.value,
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Simulation Wave Type', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E24),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2C2C35)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    // Custom wave type picker dialog
                                    showCupertinoModalPopup<void>(
                                      context: context,
                                      builder: (BuildContext context) => Container(
                                        height: 200,
                                        padding: const EdgeInsets.only(top: 6.0),
                                        margin: EdgeInsets.only(
                                          bottom: MediaQuery.of(context).viewInsets.bottom,
                                        ),
                                        color: CupertinoColors.systemBackground.resolveFrom(context),
                                        child: SafeArea(
                                          top: false,
                                          child: CupertinoPicker(
                                            magnification: 1.22,
                                            squeeze: 1.2,
                                            useMagnifier: true,
                                            itemExtent: 32.0,
                                            onSelectedItemChanged: (int selectedIndex) {
                                              final options = ['Sine Wave', 'Ramp', 'Random'];
                                              waveType.value = options[selectedIndex];
                                            },
                                            children: const [
                                              Text('Sine Wave'),
                                              Text('Ramp'),
                                              Text('Random'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(waveType.value, style: const TextStyle(color: CupertinoColors.white)),
                                      const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          const Text('', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          CupertinoButton(
                            color: isRunning.value ? CupertinoColors.destructiveRed : CupertinoColors.systemPurple,
                            onPressed: () {
                              isRunning.value = !isRunning.value;
                              if (isRunning.value) {
                                final port = portController.text;
                                final sid = slaveIdController.text;
                                logLines.value = [
                                  '[SYSTEM] Modbus Simulator started on Port $port, Slave ID $sid',
                                  '[SYSTEM] Serving registers 40001 - 40010',
                                  ...logLines.value,
                                ];
                              } else {
                                logLines.value = [
                                  '[SYSTEM] Modbus Simulator stopped',
                                  ...logLines.value,
                                ];
                              }
                            },
                            child: Text(isRunning.value ? 'Stop Simulator' : 'Start Server', style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white)),
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

        // Live Registers View
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'SIMULATOR SLAVE REGISTER DATA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2, letterSpacing: 1.0),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final val = registers.value[index];
                final address = 40001 + index;
                
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141419).withValues(alpha:0.6),
                    border: Border.all(color: CupertinoColors.systemPurple.withValues(alpha:0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$address', style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey2)),
                      const SizedBox(height: 4),
                      Text(
                        '$val',
                        style: const TextStyle(
                          fontFamily: 'SF Mono',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: 10,
            ),
          ),
        ),

        // Server Logs
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: const Text(
              'SERVER LOGS / DIALECT CONSOLE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2, letterSpacing: 1.0),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F1F24)),
              ),
              padding: const EdgeInsets.all(12),
              child: logLines.value.isEmpty
                  ? Center(child: Text('Console empty. Simulator not running.', style: TextStyle(color: CupertinoColors.systemGrey.withValues(alpha:0.5), fontSize: 12)))
                  : ListView.builder(
                      itemCount: logLines.value.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            logLines.value[index],
                            style: const TextStyle(
                              fontFamily: 'SF Mono',
                              fontSize: 11,
                              color: CupertinoColors.systemPurple,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// Simple Dropdown helper mock
class DropdownButtonHideUnderline extends StatelessWidget {
  final Widget child;
  const DropdownButtonHideUnderline({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return child;
  }
}
