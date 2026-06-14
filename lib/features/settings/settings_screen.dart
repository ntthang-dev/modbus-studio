import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/settings_provider.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final uiNotifier = ref.read(uiProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Dynamic styles for Field Mode
    final bool isField = uiState.isFieldMode;
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0A0A0C);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Visual header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Settings',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),

                  CupertinoListSection.insetGrouped(
                    header: const Text('ENVIRONMENT & VISUALS'),
                    children: [
                      CupertinoListTile(
                        title: const Text('Outdoor Field Mode'),
                        subtitle: const Text('High contrast & layout sizes for bright areas'),
                        trailing: CupertinoSwitch(
                          value: uiState.isFieldMode,
                          onChanged: (val) => uiNotifier.toggleFieldMode(),
                          activeTrackColor: CupertinoColors.systemTeal,
                        ),
                        leading: const Icon(CupertinoIcons.sun_max_fill, color: CupertinoColors.systemYellow),
                      ),
                      CupertinoListTile(
                        title: const Text('Right Details Inspector'),
                        subtitle: const Text('Show right sidebar panel on wide displays'),
                        trailing: CupertinoSwitch(
                          value: uiState.isInspectorOpen,
                          onChanged: (val) => uiNotifier.setInspectorOpen(val),
                          activeTrackColor: CupertinoColors.systemTeal,
                        ),
                        leading: const Icon(CupertinoIcons.sidebar_right, color: CupertinoColors.systemTeal),
                      ),
                    ],
                  ),
                  
                  CupertinoListSection.insetGrouped(
                    header: const Text('MODBUS DEFAULT TIMEOUTS'),
                    children: [
                      CupertinoListTile(
                        title: const Text('Response Timeout'),
                        subtitle: const Text('Wait duration before dropping connection'),
                        trailing: Text('${settings.responseTimeoutMs} ms', style: const TextStyle(color: CupertinoColors.systemGrey, fontFamily: 'SF Mono')),
                        leading: const Icon(CupertinoIcons.timer, color: CupertinoColors.systemOrange),
                        onTap: () {
                          _showTimeoutPicker(context, ref, settings.responseTimeoutMs);
                        },
                      ),
                      CupertinoListTile(
                        title: const Text('Retry Count'),
                        subtitle: const Text('Attempts before reporting failure'),
                        trailing: const Text('3 times', style: TextStyle(color: CupertinoColors.systemGrey, fontFamily: 'SF Mono')),
                        leading: const Icon(CupertinoIcons.arrow_2_circlepath, color: CupertinoColors.systemBlue),
                      ),
                    ],
                  ),

                  CupertinoListSection.insetGrouped(
                    header: const Text('DATABASE STORAGE & HYGIENE'),
                    children: [
                      CupertinoListTile(
                        title: const Text('Max Log Capping Limit'),
                        subtitle: const Text('Auto-prunes old data & logs to prevent growth'),
                        trailing: Text(
                          '${settings.maxLogRows} rows',
                          style: const TextStyle(color: CupertinoColors.systemGrey, fontFamily: 'SF Mono'),
                        ),
                        leading: const Icon(CupertinoIcons.circle_grid_hex_fill, color: CupertinoColors.systemPurple),
                        onTap: () => _showLogRowsPicker(context, ref, settings.maxLogRows),
                      ),
                    ],
                  ),

                  CupertinoListSection.insetGrouped(
                    header: const Text('SECURITY & SAFETY'),
                    children: [
                      CupertinoListTile(
                        title: const Text('Write Protection'),
                        subtitle: const Text('Require confirmation dialog before modifying registers'),
                        trailing: CupertinoSwitch(
                          value: settings.writeProtection,
                          onChanged: (val) {
                            settingsNotifier.setWriteProtection(val);
                          },
                          activeTrackColor: CupertinoColors.systemTeal,
                        ),
                        leading: const Icon(CupertinoIcons.lock_shield_fill, color: CupertinoColors.systemRed),
                      ),
                    ],
                  ),
                  
                  CupertinoListSection.insetGrouped(
                    header: const Text('SYSTEM INFO'),
                    children: const [
                      CupertinoListTile(
                        title: Text('Modbus Studio Engine'),
                        additionalInfo: Text('v2.0.0-beta'),
                        leading: Icon(CupertinoIcons.info_circle_fill, color: CupertinoColors.systemGrey),
                      ),
                      CupertinoListTile(
                        title: Text('Database Version'),
                        additionalInfo: Text('SQLite WAL (v3.42)'),
                        leading: Icon(CupertinoIcons.circle_grid_hex_fill, color: CupertinoColors.systemPurple),
                      ),
                      CupertinoListTile(
                        title: Text('Rust Backend Bridge'),
                        additionalInfo: Text('FRB v2.12.0'),
                        leading: Icon(CupertinoIcons.hammer_fill, color: CupertinoColors.systemOrange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogRowsPicker(BuildContext context, WidgetRef ref, int currentLimit) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Database Log Capping Limit'),
        message: const Text('Select the maximum historical log records to preserve.'),
        actions: [500, 1000, 5000, 10000].map((limit) {
          final isSelected = currentLimit == limit;
          return CupertinoActionSheetAction(
            onPressed: () {
              ref.read(settingsProvider.notifier).setMaxLogRows(limit);
              Navigator.pop(context);
            },
            child: Text(
              '$limit rows',
              style: TextStyle(
                color: isSelected ? CupertinoColors.systemTeal : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTimeoutPicker(BuildContext context, WidgetRef ref, int currentTimeout) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Response Timeout'),
        message: const Text('Select connection drop wait timeout.'),
        actions: [1000, 2000, 3000, 5000].map((timeout) {
          final isSelected = currentTimeout == timeout;
          return CupertinoActionSheetAction(
            onPressed: () {
              ref.read(settingsProvider.notifier).setResponseTimeoutMs(timeout);
              Navigator.pop(context);
            },
            child: Text(
              '$timeout ms',
              style: TextStyle(
                color: isSelected ? CupertinoColors.systemTeal : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
