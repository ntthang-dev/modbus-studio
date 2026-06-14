import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/automation/automation_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class AutomationScreen extends HookConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final connState = ref.watch(connectionProvider);
    final automationState = ref.watch(automationProvider);
    final automationNotifier = ref.read(automationProvider.notifier);

    // Styling
    final bool isField = uiState.isFieldMode;
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0A0A0C);
    final Color cardColor = isField ? CupertinoColors.white : const Color(0xFF121216);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;
    final Color subtextColor = isField ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey;
    final Color borderColor = isField ? CupertinoColors.systemGrey4 : const Color(0xFF1F1F24);

    // Modal state
    final showAddModal = useState<bool>(false);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Screen Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automation Console',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scheduled write triggers (FC 05 / FC 06)',
                              style: TextStyle(fontSize: 13, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        color: CupertinoColors.systemTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () => showAddModal.value = true,
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.plus, size: 14, color: CupertinoColors.white),
                            SizedBox(width: 6),
                            Text('Add Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Connection state warning
              if (!connState.isConnected)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemOrange.withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CupertinoColors.systemOrange.withValues(alpha:0.4), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.systemOrange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Device Offline. Tasks will execute once a connection is established.',
                              style: TextStyle(color: isField ? CupertinoColors.systemOrange : CupertinoColors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Scheduled Tasks List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildTasksList(
                  context,
                  automationState.scheduledWrites,
                  automationNotifier,
                  cardColor,
                  textColor,
                  subtextColor,
                  borderColor,
                ),
              ),

              // Live Logs Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE EXECUTION LOGGER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: subtextColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (automationState.logs.isNotEmpty)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => automationNotifier.clearLogs(),
                          child: const Text('Clear Log', style: TextStyle(fontSize: 12, color: CupertinoColors.systemRed)),
                        ),
                    ],
                  ),
                ),
              ),

              // Live Logs Console
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isField ? CupertinoColors.white : const Color(0xFF0F0F12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: automationState.logs.isEmpty
                        ? Center(
                            child: Text(
                              'No execution logs yet.',
                              style: TextStyle(color: subtextColor.withValues(alpha:0.5), fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: automationState.logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  automationState.logs[index],
                                  style: const TextStyle(
                                    fontFamily: 'SF Mono',
                                    fontSize: 11,
                                    color: CupertinoColors.systemGreen,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),

          // Modal Popup sheet
          if (showAddModal.value)
            _buildAddTaskModal(
              context,
              showAddModal,
              automationNotifier,
              cardColor,
              textColor,
              subtextColor,
              borderColor,
            ),
        ],
      ),
    );
  }

  Widget _buildTasksList(
    BuildContext context,
    List<ScheduledWrite> tasks,
    AutomationNotifier notifier,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    if (tasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.timer, size: 40, color: subtextColor.withValues(alpha:0.4)),
              const SizedBox(height: 12),
              Text(
                'No scheduled writes configured',
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "Add Task" to configure periodic automated writes.',
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final task = tasks[index];
          final typeLabel = task.isCoil ? 'Coil' : 'Register';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    task.isCoil ? CupertinoIcons.bolt_horizontal_fill : CupertinoIcons.square_grid_2x2_fill,
                    color: CupertinoColors.systemTeal,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$typeLabel ${task.address}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Write value ${task.value} every ${task.intervalSecs}s',
                          style: TextStyle(fontSize: 12, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: task.isEnabled,
                    onChanged: (val) => notifier.toggleScheduledWrite(task),
                    activeTrackColor: CupertinoColors.systemTeal,
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (task.id != null) {
                        notifier.deleteScheduledWrite(task.id!);
                      }
                    },
                    child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed, size: 18),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: tasks.length,
      ),
    );
  }

  Widget _buildAddTaskModal(
    BuildContext context,
    ValueNotifier<bool> showAddModal,
    AutomationNotifier notifier,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return HookBuilder(
      builder: (context) {
        final addressController = useTextEditingController(text: '40005');
        final valueController = useTextEditingController(text: '1');
        final intervalController = useTextEditingController(text: '10');
        final isCoilState = useState<bool>(false);

        return Positioned.fill(
          child: Container(
            color: CupertinoColors.black.withValues(alpha:0.6),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Configure Scheduled Write',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => showAddModal.value = false,
                            child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Task Type Segmented Selector
                      Text('Write Target Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                      const SizedBox(height: 6),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: isCoilState.value,
                        children: const {
                          false: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Holding Register (FC 06)')),
                          true: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Coil (FC 05)')),
                        },
                        onValueChanged: (val) {
                          if (val != null) {
                            isCoilState.value = val;
                            if (val) {
                              addressController.text = '1';
                            } else {
                              addressController.text = '40005';
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Target Address
                      Text('Modbus Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: addressController,
                        placeholder: isCoilState.value ? 'e.g. 1' : 'e.g. 40005',
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24).withValues(alpha:0.1),
                          border: Border.all(color: borderColor, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      const SizedBox(height: 14),

                      // Value to write
                      Text('Value to Write', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: valueController,
                        placeholder: '1',
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24).withValues(alpha:0.1),
                          border: Border.all(color: borderColor, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      const SizedBox(height: 14),

                      // Interval in seconds
                      Text('Trigger Interval (Seconds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: intervalController,
                        placeholder: '10',
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24).withValues(alpha:0.1),
                          border: Border.all(color: borderColor, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      CupertinoButton.filled(
                        child: const Text('Save Automation Task', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final addr = int.tryParse(addressController.text.trim());
                          final val = int.tryParse(valueController.text.trim());
                          final interval = int.tryParse(intervalController.text.trim());

                          if (addr == null || val == null || interval == null || interval <= 0) {
                            return;
                          }

                          notifier.saveScheduledWrite(
                            ScheduledWrite(
                              id: null,
                              address: addr,
                              value: val,
                              intervalSecs: interval,
                              isCoil: isCoilState.value,
                              isEnabled: true,
                            ),
                          );
                          showAddModal.value = false;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
