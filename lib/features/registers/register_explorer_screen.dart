import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/inspector/widgets/write_control_card.dart';
import 'package:modbus_studio/features/inspector/widgets/historian_chart.dart';
import 'package:modbus_studio/features/registers/register_decoder.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class RegisterExplorerScreen extends HookConsumerWidget {
  const RegisterExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final libraryState = ref.watch(deviceLibraryProvider);
    final registerConfigs = ref.watch(registerConfigProvider);

    // Track which register is selected for chart preview
    final selectedRegisterIndex = useState<int>(0);

    // Controller hooks for dynamic header
    final selectedFC = useState<int>(connState.functionCode);
    final startAddressController = useTextEditingController(text: connState.startAddress.toString());
    final quantityController = useTextEditingController(text: connState.quantity.toString());

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
                color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
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

    final addressPrefix = switch (connState.functionCode) {
      1 => 1,
      2 => 10001,
      3 => 40001,
      4 => 30001,
      _ => 40001,
    };

    final selectedAddress = addressPrefix + connState.startAddress + selectedRegisterIndex.value;

    return CustomScrollView(
      slivers: [
        // Polling Configuration Header (Liquid Control Deck design)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E1E28), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemTeal.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.settings_solid, color: CupertinoColors.systemTeal, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'MODBUS POLL CONTEXT',
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: CupertinoColors.systemGrey2,
                        letterSpacing: 1.2,
                        fontFamily: 'SF Mono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Function Code Dropdown
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Function Code', style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              showCupertinoModalPopup(
                                context: context,
                                builder: (context) => CupertinoActionSheet(
                                  title: const Text('Select Function Code'),
                                  actions: [
                                    CupertinoActionSheetAction(
                                      onPressed: () {
                                        selectedFC.value = 1;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('FC 01: Read Coils'),
                                    ),
                                    CupertinoActionSheetAction(
                                      onPressed: () {
                                        selectedFC.value = 2;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('FC 02: Read Discrete Inputs'),
                                    ),
                                    CupertinoActionSheetAction(
                                      onPressed: () {
                                        selectedFC.value = 3;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('FC 03: Read Holding Registers'),
                                    ),
                                    CupertinoActionSheetAction(
                                      onPressed: () {
                                        selectedFC.value = 4;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('FC 04: Read Input Registers'),
                                    ),
                                  ],
                                  cancelButton: CupertinoActionSheetAction(
                                    isDefaultAction: true,
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      switch (selectedFC.value) {
                                        1 => 'FC 01: Coils',
                                        2 => 'FC 02: Inputs',
                                        3 => 'FC 03: Holding Regs',
                                        4 => 'FC 04: Input Regs',
                                        _ => 'FC 03: Holding Regs',
                                      },
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(CupertinoIcons.chevron_down, size: 12, color: CupertinoColors.systemGrey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Start Address
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Address', style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
                          const SizedBox(height: 4),
                          CupertinoTextField(
                            controller: startAddressController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            placeholder: '0',
                            style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontFamily: 'SF Mono'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E26),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Quantity
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Count', style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
                          const SizedBox(height: 4),
                          CupertinoTextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            placeholder: '10',
                            style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontFamily: 'SF Mono'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E26),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Apply Button
                    Column(
                      children: [
                        const Text('', style: TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: CupertinoColors.systemTeal,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () {
                            final startAddr = int.tryParse(startAddressController.text) ?? 0;
                            final quantity = int.tryParse(quantityController.text) ?? 10;
                            // Clamp quantity to sane limits to prevent crashing devices
                            final safeQty = quantity.clamp(1, 125);
                            quantityController.text = safeQty.toString();

                            connNotifier.updatePollConfig(selectedFC.value, startAddr, safeQty);
                          },
                          child: const Text(
                            'Poll',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CupertinoColors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                final address = addressPrefix + connState.startAddress + index;
                final tag = libraryState.activeTags[address];
                final config = registerConfigs[address];

                // Decode display value
                final defaultType = (connState.functionCode == 1 || connState.functionCode == 2) ? 'Boolean' : 'Uint16';
                final decodedText = RegisterDecoder.format(
                  rawRegisters: connState.registers,
                  startIndex: index,
                  dataType: config?.dataType ?? defaultType,
                  multiplier: config?.multiplier ?? 1.0,
                  offset: config?.offset ?? 0.0,
                  unit: config?.unit ?? '',
                );
                
                return _buildRegisterTile(
                  context,
                  ref,
                  connState.activeIp ?? '',
                  index: index,
                  address: address,
                  rawValue: value,
                  decodedValue: decodedText,
                  tag: tag,
                  isSelected: isSelected,
                  config: config,
                  onTap: () {
                    selectedRegisterIndex.value = index;
                  },
                );
              },
              childCount: connState.registers.isNotEmpty ? connState.registers.length : connState.quantity,
            ),
          ),
        ),

        // Historian Chart and Write controls section for selected register
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
                
                // Embed the write panel (Writes are allowed only for writable FCs: Coils FC01 and Holding Registers FC03)
                if (connState.functionCode == 1 || connState.functionCode == 3)
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
    BuildContext context,
    WidgetRef ref,
    String deviceKey, {
    required int index,
    required int address,
    required int rawValue,
    required String decodedValue,
    String? tag,
    required bool isSelected,
    RegisterConfig? config,
    required VoidCallback onTap,
  }) {
    final hexString = '0x${rawValue.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? CupertinoColors.systemTeal.withValues(alpha: 0.12)
              : const Color(0xFF141419).withValues(alpha: 0.6),
          border: Border.all(
            color: isSelected 
                ? CupertinoColors.systemTeal 
                : CupertinoColors.systemTeal.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tag != null ? '$address: $tag' : 'Reg $address',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey2, 
                      fontSize: 12, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ),
                
                // Quick Cog to configure this register specifically
                GestureDetector(
                  onTap: () => _showConfigureDialog(context, ref, deviceKey, address, config),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 14,
                      color: isSelected ? cupertinoTealAccent : CupertinoColors.systemGrey2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    decodedValue,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Mono',
                      color: isSelected ? CupertinoColors.white : CupertinoColors.systemTeal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hexString,
                      style: const TextStyle(
                        fontFamily: 'SF Mono',
                        color: CupertinoColors.systemGrey,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      config?.dataType ?? 'Uint16',
                      style: const TextStyle(
                        fontSize: 9,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0)
     .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 150.ms);
  }

  void _showConfigureDialog(
    BuildContext context,
    WidgetRef ref,
    String deviceKey,
    int address,
    RegisterConfig? currentConfig,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return _RegisterConfigDialog(
          deviceKey: deviceKey,
          address: address,
          currentConfig: currentConfig,
        );
      },
    );
  }
}

class _RegisterConfigDialog extends HookConsumerWidget {
  final String deviceKey;
  final int address;
  final RegisterConfig? currentConfig;

  const _RegisterConfigDialog({
    required this.deviceKey,
    required this.address,
    this.currentConfig,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = useState<String>(currentConfig?.dataType ?? 'Uint16');
    final useScaling = useState<bool>(
      currentConfig != null && (currentConfig!.multiplier != 1.0 || currentConfig!.offset != 0.0 || currentConfig!.unit.isNotEmpty),
    );
    final multiplierController = useTextEditingController(
      text: currentConfig?.multiplier.toString() ?? '1.0',
    );
    final offsetController = useTextEditingController(
      text: currentConfig?.offset.toString() ?? '0.0',
    );
    final unitController = useTextEditingController(
      text: currentConfig?.unit ?? '',
    );

    return CupertinoAlertDialog(
      title: Text('Configure Register $address'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Data Type dropdown selection (Cupertino action sheet styled)
            GestureDetector(
              onTap: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    title: const Text('Select Data Type'),
                    actions: [
                      'Boolean',
                      'Uint16',
                      'Int16',
                      'Uint32',
                      'Int32',
                      'Float32',
                      'Hex',
                      'Binary',
                    ].map((type) {
                      return CupertinoActionSheetAction(
                        onPressed: () {
                          selectedType.value = type;
                          Navigator.pop(context);
                        },
                        child: Text(type),
                      );
                    }).toList(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedType.value, style: const TextStyle(color: CupertinoColors.white, fontSize: 13)),
                    const Icon(CupertinoIcons.chevron_down, size: 12, color: CupertinoColors.systemGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Use Custom Scaling Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Linear Scaling', style: TextStyle(fontSize: 12, color: CupertinoColors.white)),
                CupertinoSwitch(
                  value: useScaling.value,
                  onChanged: (val) {
                    useScaling.value = val;
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (useScaling.value) ...[
              // Multiplier Input
              CupertinoTextField(
                controller: multiplierController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                placeholder: 'Multiplier (m)',
                prefix: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('m:', style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
                style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                ),
              ),
              const SizedBox(height: 8),

              // Offset Input
              CupertinoTextField(
                controller: offsetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                placeholder: 'Offset (c)',
                prefix: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('c:', style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
                style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                ),
              ),
              const SizedBox(height: 8),

              // Suffix Unit Input
              CupertinoTextField(
                controller: unitController,
                placeholder: 'Unit (e.g. °C, V, PSI)',
                prefix: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('Unit:', style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
                style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2C2C38), width: 1.0),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            final multiplier = useScaling.value ? (double.tryParse(multiplierController.text) ?? 1.0) : 1.0;
            final offset = useScaling.value ? (double.tryParse(offsetController.text) ?? 0.0) : 0.0;
            final unit = useScaling.value ? unitController.text.trim() : '';

            ref.read(registerConfigProvider.notifier).saveConfig(
              RegisterConfig(
                deviceKey: deviceKey,
                address: address,
                dataType: selectedType.value,
                multiplier: multiplier,
                offset: offset,
                unit: unit,
              ),
            );

            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

const cupertinoTealAccent = Color(0xFF64D2FF);
