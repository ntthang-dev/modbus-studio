import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

String _formatTimestamp(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final y = dt.year;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm:$ss';
}

class AlarmsScreen extends HookConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final alarmState = ref.watch(alarmProvider);
    final alarmNotifier = ref.read(alarmProvider.notifier);

    // Colors adjusted for Field Mode (Outdoor High Contrast)
    final bool isField = uiState.isFieldMode;
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0A0A0C);
    final Color cardColor = isField ? CupertinoColors.white : const Color(0xFF141419);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;
    final Color subtextColor = isField ? CupertinoColors.secondaryLabel : CupertinoColors.systemGrey2;
    final Color borderColor = isField ? const Color(0xFFD1D1D6) : const Color(0xFF2C2C35);

    // Track active rule-editing / creation modal state
    final showAddModal = useState<bool>(false);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbar Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarms Console',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${alarmState.rules.length} Active Rules | ${alarmState.logs.length} Historical Logs',
                              style: TextStyle(fontSize: 12, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            color: CupertinoColors.systemRed.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: alarmState.logs.isEmpty 
                                ? null 
                                : () => _showClearConfirmDialog(context, alarmNotifier),
                            child: const Text(
                              'Clear Logs',
                              style: TextStyle(color: CupertinoColors.systemRed, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () {
                              showAddModal.value = true;
                            },
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.add, size: 16),
                                SizedBox(width: 4),
                                Text('Add Rule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // Main Layout (Responsive Side-by-Side on Desktop, Column on mobile)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool useRow = constraints.maxWidth >= 720;
                      if (useRow) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Panel: Rules Configuration
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                                ),
                                child: _buildRulesPanel(context, alarmState, alarmNotifier, cardColor, textColor, subtextColor, borderColor),
                              ),
                            ),
                            // Right Panel: Alarms Log Historian
                            Expanded(
                              flex: 5,
                              child: _buildLogsPanel(context, alarmState, cardColor, textColor, subtextColor, borderColor),
                            ),
                          ],
                        );
                      } else {
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Active Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 260,
                                child: _buildRulesPanel(context, alarmState, alarmNotifier, cardColor, textColor, subtextColor, borderColor),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Alarms Log History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                              ),
                            ),
                            SliverFillRemaining(
                              child: _buildLogsPanel(context, alarmState, cardColor, textColor, subtextColor, borderColor),
                            )
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Add Rule Sliding Sheet Overlay
          if (showAddModal.value)
            _buildAddRuleModal(context, showAddModal, alarmNotifier, cardColor, textColor, subtextColor, borderColor),
        ],
      ),
    );
  }

  Widget _buildRulesPanel(
    BuildContext context,
    AlarmState state,
    AlarmNotifier notifier,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    if (state.rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.bell_slash_fill, size: 48, color: subtextColor.withValues(alpha:0.4)),
            const SizedBox(height: 12),
            Text('No active alarm rules', style: TextStyle(color: subtextColor, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.rules.length,
      itemBuilder: (context, index) {
        final rule = state.rules[index];
        final isCritical = rule.severity == 'Critical';
        final accentColor = isCritical ? CupertinoColors.systemRed : CupertinoColors.systemOrange;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 38,
                decoration: BoxDecoration(
                  color: rule.isEnabled ? accentColor : CupertinoColors.systemGrey,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rule.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: rule.isEnabled 
                                ? accentColor.withValues(alpha:0.15)
                                : CupertinoColors.systemGrey.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rule.severity,
                            style: TextStyle(
                              color: rule.isEnabled ? accentColor : CupertinoColors.systemGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Address: ${rule.registerAddress} ${rule.condition} ${rule.threshold}',
                      style: TextStyle(fontSize: 12, color: subtextColor, fontFamily: 'SF Mono'),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: rule.isEnabled,
                onChanged: (val) {
                  notifier.addRule(AlarmRule(
                    id: rule.id,
                    name: rule.name,
                    registerAddress: rule.registerAddress,
                    condition: rule.condition,
                    threshold: rule.threshold,
                    severity: rule.severity,
                    isEnabled: val,
                  ));
                },
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (rule.id != null) {
                    notifier.deleteRule(rule.id!.toInt());
                  }
                },
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed, size: 20),
              )
            ],
          ),
        ).animate().fadeIn().slideX(begin: -0.05, end: 0, duration: 200.ms * (index + 1).clamp(1, 4));
      },
    );
  }

  Widget _buildLogsPanel(
    BuildContext context,
    AlarmState state,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    if (state.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.square_list_fill, size: 48, color: subtextColor.withValues(alpha:0.4)),
            const SizedBox(height: 12),
            Text('Alarm log is empty', style: TextStyle(color: subtextColor, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final log = state.logs[index];
        final severity = log.severity;
        final isCritical = severity == 'Critical';
        final isWarning = severity == 'Warning';

        Color badgeColor;
        Color badgeBg;
        if (isCritical) {
          badgeColor = CupertinoColors.systemRed;
          badgeBg = CupertinoColors.systemRed.withValues(alpha:0.12);
        } else if (isWarning) {
          badgeColor = CupertinoColors.systemOrange;
          badgeBg = CupertinoColors.systemOrange.withValues(alpha:0.12);
        } else {
          badgeColor = CupertinoColors.systemGreen;
          badgeBg = CupertinoColors.systemGreen.withValues(alpha:0.12);
        }

        final timeStr = _formatTimestamp(log.timestamp.toInt());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: subtextColor, fontFamily: 'SF Mono'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                log.message,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.3),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Reg Address: ${log.registerAddress}',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Value Polled: ${log.value}',
                    style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 150.ms);
      },
    );
  }

  Widget _buildAddRuleModal(
    BuildContext context,
    ValueNotifier<bool> showModal,
    AlarmNotifier notifier,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Semi-transparent dim background
          GestureDetector(
            onTap: () => showModal.value = false,
            child: Container(
              color: CupertinoColors.black.withValues(alpha:0.6),
            ),
          ),

          // Sliding sheet form container
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 420,
              height: 480,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha:0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AddRuleForm(
                  onCancel: () => showModal.value = false,
                  onSubmit: (rule) {
                    notifier.addRule(rule);
                    showModal.value = false;
                  },
                  textColor: textColor,
                  borderColor: borderColor,
                  subtextColor: subtextColor,
                ),
              ),
            ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
          )
        ],
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context, AlarmNotifier notifier) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Clear Alarm Logs'),
          content: const Text('Are you sure you want to permanently clear all historical alarm notifications? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Clear All'),
              onPressed: () {
                notifier.clearLogs();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}

class AddRuleForm extends HookWidget {
  final VoidCallback onCancel;
  final Function(AlarmRule) onSubmit;
  final Color textColor;
  final Color borderColor;
  final Color subtextColor;

  const AddRuleForm({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    required this.textColor,
    required this.borderColor,
    required this.subtextColor,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: 'High Boiler Temperature');
    final addressController = useTextEditingController(text: '40001');
    final thresholdController = useTextEditingController(text: '800');
    
    final conditionState = useState<String>('>');
    final severityState = useState<String>('Critical');

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Configure Alarm Rule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onCancel,
                child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey, size: 24),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // Rule Name Input
          Text('Rule Tag / Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: nameController,
            placeholder: 'e.g. Tank Low Level',
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24).withValues(alpha:0.3),
              border: Border.all(color: borderColor, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          const SizedBox(height: 14),

          // Address & Threshold row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modbus Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: addressController,
                      placeholder: '40001',
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24).withValues(alpha:0.3),
                        border: Border.all(color: borderColor, width: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trigger Threshold', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: thresholdController,
                      placeholder: '800',
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24).withValues(alpha:0.3),
                        border: Border.all(color: borderColor, width: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Condition Picker
          Text('Trigger Condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
          const SizedBox(height: 6),
          Row(
            children: ['>', '<', '==', '!='].map((cond) {
              final isSelected = conditionState.value == cond;
              return Expanded(
                child: GestureDetector(
                  onTap: () => conditionState.value = cond,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? CupertinoColors.systemTeal 
                          : const Color(0xFF1E1E24).withValues(alpha:0.3),
                      border: Border.all(
                        color: isSelected ? CupertinoColors.systemTeal : borderColor,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cond,
                      style: TextStyle(
                        color: isSelected ? CupertinoColors.white : textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Severity Picker
          Text('Alarm Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
          const SizedBox(height: 6),
          Row(
            children: ['Warning', 'Critical'].map((sev) {
              final isSelected = severityState.value == sev;
              final accentColor = sev == 'Critical' ? CupertinoColors.systemRed : CupertinoColors.systemOrange;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    severityState.value = sev;
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? accentColor 
                          : const Color(0xFF1E1E24).withValues(alpha:0.3),
                      border: Border.all(
                        color: isSelected ? accentColor : borderColor,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sev,
                      style: TextStyle(
                        color: isSelected ? CupertinoColors.white : textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const Spacer(),

          // Form submission
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(8),
            onPressed: () {
              final name = nameController.text.trim();
              final address = int.tryParse(addressController.text.trim()) ?? 40001;
              final threshold = int.tryParse(thresholdController.text.trim()) ?? 0;

              if (name.isEmpty) return;

              onSubmit(AlarmRule(
                id: null,
                name: name,
                registerAddress: address,
                condition: conditionState.value,
                threshold: threshold,
                severity: severityState.value,
                isEnabled: true,
              ));
            },
            child: const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
