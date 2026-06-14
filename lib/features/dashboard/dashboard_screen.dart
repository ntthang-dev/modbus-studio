import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/dashboard/widgets/hmi_radial_gauge.dart';
import 'package:modbus_studio/features/dashboard/widgets/hmi_tank_level.dart';

class HmiWidgetConfig {
  final String id;
  final String title;
  final String type; // 'radial' or 'tank'
  final int registerAddress; // e.g. 40001
  final int minVal;
  final int maxVal;

  HmiWidgetConfig({
    required this.id,
    required this.title,
    required this.type,
    this.registerAddress = 40001,
    this.minVal = 0,
    this.maxVal = 1000,
  });

  HmiWidgetConfig copyWith({
    String? title,
    int? registerAddress,
    int? minVal,
    int? maxVal,
  }) {
    return HmiWidgetConfig(
      id: id,
      title: title ?? this.title,
      type: type,
      registerAddress: registerAddress ?? this.registerAddress,
      minVal: minVal ?? this.minVal,
      maxVal: maxVal ?? this.maxVal,
    );
  }
}

class DashboardNotifier extends Notifier<List<HmiWidgetConfig>> {
  @override
  List<HmiWidgetConfig> build() => [];

  void addWidget(String type) {
    final count = state.where((w) => w.type == type).length + 1;
    final title = type == 'radial' ? 'Radial Gauge $count' : 'Tank Level $count';
    state = [
      ...state,
      HmiWidgetConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        type: type,
        registerAddress: 40001 + state.length,
      ),
    ];
  }

  void removeWidget(String id) {
    state = state.where((w) => w.id != id).toList();
  }

  void updateWidget(String id, HmiWidgetConfig newConfig) {
    state = state.map((w) => w.id == id ? newConfig : w).toList();
  }
}

final dashboardNotifierProvider = NotifierProvider<DashboardNotifier, List<HmiWidgetConfig>>(() {
  return DashboardNotifier();
});

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);

    return CustomScrollView(
      slivers: [
        // Configuration Title Row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HMI DASHBOARD BUILDER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemGrey2,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connState.isConnected 
                      ? 'Connected: Polling Bound Registers' 
                      : 'Offline Mode: Setup Widget Configurations',
                  style: TextStyle(
                    fontSize: 14,
                    color: connState.isConnected ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Widget Preset Pickers
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildPresetCard(
                  title: 'Radial Dial',
                  desc: 'Circular dial gauge',
                  icon: CupertinoIcons.gauge,
                  color: CupertinoColors.systemTeal,
                  onTap: () => notifier.addWidget('radial'),
                ),
                const SizedBox(width: 16),
                _buildPresetCard(
                  title: 'Tank Level',
                  desc: 'Vertical tank indicator',
                  icon: CupertinoIcons.drop_fill,
                  color: CupertinoColors.systemBlue,
                  onTap: () => notifier.addWidget('tank'),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Widgets Grid or Empty State
        if (widgets.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.square_grid_3x2_fill,
                      size: 64,
                      color: CupertinoColors.systemGrey.withValues(alpha:0.2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No HMI widgets added yet. Tap a preset card above to populate your workstation canvas.',
                      style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final config = widgets[index];
                  final regIdx = config.registerAddress - 40001;
                  final regVal = (regIdx >= 0 && regIdx < connState.registers.length) 
                      ? connState.registers[regIdx] 
                      : 0;

                  final child = config.type == 'radial'
                      ? HmiRadialGauge(
                          title: config.title,
                          value: regVal,
                          minVal: config.minVal,
                          maxVal: config.maxVal,
                          accentColor: CupertinoColors.systemTeal,
                          onConfigure: () => _showConfigureSheet(context, ref, config),
                          onWriteValue: connState.isConnected 
                              ? (val) => connNotifier.writeRegister(regIdx, val) 
                              : null,
                        )
                      : HmiTankLevel(
                          title: config.title,
                          value: regVal,
                          minVal: config.minVal,
                          maxVal: config.maxVal,
                          accentColor: CupertinoColors.systemBlue,
                          onConfigure: () => _showConfigureSheet(context, ref, config),
                          onWriteValue: connState.isConnected 
                              ? (val) => connNotifier.writeRegister(regIdx, val) 
                              : null,
                        );

                  return child.animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
                },
                childCount: widgets.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C35), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfigureSheet(BuildContext context, WidgetRef ref, HmiWidgetConfig config) {
    final nameController = TextEditingController(text: config.title);
    final addressController = TextEditingController(text: config.registerAddress.toString());
    final minController = TextEditingController(text: config.minVal.toString());
    final maxController = TextEditingController(text: config.maxVal.toString());

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text('Configure ${config.type == 'radial' ? 'Dial' : 'Tank'} Widget'),
          message: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Widget Name', style: TextStyle(fontSize: 12), textAlign: TextAlign.left),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'e.g. Temperature Sensor',
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Register Address (40001+)', style: TextStyle(fontSize: 12), textAlign: TextAlign.left),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: addressController,
                  placeholder: '40001',
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Min Value', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          CupertinoTextField(
                            controller: minController,
                            placeholder: '0',
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: CupertinoColors.white),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Value', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          CupertinoTextField(
                            controller: maxController,
                            placeholder: '1000',
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: CupertinoColors.white),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('Save Settings'),
              onPressed: () {
                final addr = int.tryParse(addressController.text.trim()) ?? 40001;
                final minV = int.tryParse(minController.text.trim()) ?? 0;
                final maxV = int.tryParse(maxController.text.trim()) ?? 1000;
                
                final updated = config.copyWith(
                  title: nameController.text.trim(),
                  registerAddress: addr,
                  minVal: minV,
                  maxVal: maxV,
                );

                ref.read(dashboardNotifierProvider.notifier).updateWidget(config.id, updated);
                Navigator.pop(context);
              },
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(dashboardNotifierProvider.notifier).removeWidget(config.id);
                Navigator.pop(context);
              },
              child: const Text('Remove Widget'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }
}
