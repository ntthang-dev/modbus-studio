import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';
import 'package:modbus_studio/features/hub/site_provider.dart';


class ConnectionHubScreen extends HookConsumerWidget {
  const ConnectionHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiNotifier = ref.read(uiProvider.notifier);
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final libraryState = ref.watch(deviceLibraryProvider);
    final siteState = ref.watch(siteProvider);

    // Form inputs
    final ipController = useTextEditingController(text: '192.168.1.10');
    final portController = useTextEditingController(text: '502');
    final portNameController = useTextEditingController(text: '/dev/ttyUSB0');
    final baudRateController = useTextEditingController(text: '9600');
    final slaveIdController = useTextEditingController(text: '1');
    final profileNameController = useTextEditingController(text: '');

    // Connection configuration states
    // 0 = TCP, 1 = RTU_TCP, 2 = SERIAL
    final selectedTab = useState<int>(0);
    final parityState = useState<String>('None');
    final dataBitsState = useState<int>(8);
    final stopBitsState = useState<int>(1);
    final selectedSiteId = useState<int?>(null);

    final String greeting = _getGreeting();

    // Setup helper to connect using the active form values
    Future<void> handleConnect() async {
      final slaveId = int.tryParse(slaveIdController.text.trim()) ?? 1;
      
      ConnectionConfig config;
      if (selectedTab.value == 0 || selectedTab.value == 1) {
        config = ConnectionConfig(
          protocolType: selectedTab.value == 0 ? 'TCP' : 'RTU_TCP',
          ip: ipController.text.trim(),
          port: int.tryParse(portController.text.trim()) ?? 502,
          portName: null,
          baudRate: null,
          parity: null,
          dataBits: null,
          stopBits: null,
        );
      } else {
        config = ConnectionConfig(
          protocolType: 'SERIAL',
          ip: null,
          port: null,
          portName: portNameController.text.trim(),
          baudRate: int.tryParse(baudRateController.text.trim()) ?? 9600,
          parity: parityState.value,
          dataBits: dataBitsState.value,
          stopBits: stopBitsState.value,
        );
      }

      await connNotifier.connect(config, slaveId: slaveId);
      if (ref.read(connectionProvider).isConnected) {
        uiNotifier.setScreen(AppScreen.registers);
      }
    }

    // Save profile to database
    Future<void> handleSaveProfile() async {
      final name = profileNameController.text.trim();
      if (name.isEmpty) return;

      ConnectionConfig config;
      if (selectedTab.value == 0 || selectedTab.value == 1) {
        config = ConnectionConfig(
          protocolType: selectedTab.value == 0 ? 'TCP' : 'RTU_TCP',
          ip: ipController.text.trim(),
          port: int.tryParse(portController.text.trim()) ?? 502,
          portName: null,
          baudRate: null,
          parity: null,
          dataBits: null,
          stopBits: null,
        );
      } else {
        config = ConnectionConfig(
          protocolType: 'SERIAL',
          ip: null,
          port: null,
          portName: portNameController.text.trim(),
          baudRate: int.tryParse(baudRateController.text.trim()) ?? 9600,
          parity: parityState.value,
          dataBits: dataBitsState.value,
          stopBits: stopBitsState.value,
        );
      }

      final newProfile = ConnectionProfile(
        id: null,
        name: name,
        config: config,
        isFavorite: false,
        lastUsed: DateTime.now().millisecondsSinceEpoch,
        siteId: selectedSiteId.value,
      );

      await connNotifier.saveProfile(newProfile);
      profileNameController.clear();
      selectedSiteId.value = null;
      await ref.read(siteProvider.notifier).loadAll();
    }

    return CustomScrollView(
      slivers: [
        // Welcome Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemTeal,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Modbus Studio Workstation',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                    fontFamily: '.SF Pro Display',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consolidated SCADA utility for automation engineers. Ready to inspect, log, or simulate.',
                  style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
        ),

        // Quick Connect Card & Favorites Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Connect Form Panel
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419).withValues(alpha:0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF23232C)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.bolt_horizontal_circle_fill, color: CupertinoColors.systemTeal, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Connection Wizard',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Protocol selector tab
                        CupertinoSlidingSegmentedControl<int>(
                          groupValue: selectedTab.value,
                          children: const {
                            0: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('TCP/IP', style: TextStyle(fontSize: 12))),
                            1: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('RTU over TCP', style: TextStyle(fontSize: 12))),
                            2: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('RTU Serial', style: TextStyle(fontSize: 12))),
                          },
                          onValueChanged: (val) {
                            if (val != null) selectedTab.value = val;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Dynamic parameters form
                        if (selectedTab.value == 0 || selectedTab.value == 1) ...[
                          _buildFormGroup(
                            title: 'Network Settings',
                            children: [
                              const Text('IP Address', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                              const SizedBox(height: 6),
                              CupertinoTextField(
                                controller: ipController,
                                placeholder: '192.168.1.100',
                                style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141419),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF23232C)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Port', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                        const SizedBox(height: 6),
                                        CupertinoTextField(
                                          controller: portController,
                                          placeholder: '502',
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141419),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF23232C)),
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
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Slave ID (Unit ID)', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Slave ID', 'The Modbus address of the device (1-247). Unit ID is used in TCP encapsulation to route requests.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoTextField(
                                          controller: slaveIdController,
                                          placeholder: '1',
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141419),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF23232C)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildFormGroup(
                            title: 'Serial Link',
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Serial Port', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                        const SizedBox(height: 6),
                                        CupertinoTextField(
                                          controller: portNameController,
                                          placeholder: '/dev/ttyUSB0 or COM1',
                                          style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141419),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF23232C)),
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
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Baud Rate', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Baud Rate', 'The speed of communication over the serial link in bits per second (e.g. 9600, 19200, 115200). Must match device config.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoTextField(
                                          controller: baudRateController,
                                          placeholder: '9600',
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141419),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF23232C)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          _buildFormGroup(
                            title: 'Transmission Settings',
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Parity', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Parity', 'Error-detection bit appended to each data byte. Common options are None, Even, or Odd.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoSlidingSegmentedControl<String>(
                                          groupValue: parityState.value,
                                          children: const {
                                            'None': Text('None', style: TextStyle(fontSize: 10)),
                                            'Even': Text('Even', style: TextStyle(fontSize: 10)),
                                            'Odd': Text('Odd', style: TextStyle(fontSize: 10)),
                                          },
                                          onValueChanged: (val) {
                                            if (val != null) parityState.value = val;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Data Bits', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Data Bits', 'Number of bits representing a single data character. Modbus RTU almost always uses 8 data bits.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoSlidingSegmentedControl<int>(
                                          groupValue: dataBitsState.value,
                                          children: const {
                                            7: Text('7', style: TextStyle(fontSize: 10)),
                                            8: Text('8', style: TextStyle(fontSize: 10)),
                                          },
                                          onValueChanged: (val) {
                                            if (val != null) dataBitsState.value = val;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Stop Bits', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Stop Bits', 'Bits signaling the end of a byte transmission. Usually 1 or 2 stop bits are used.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoSlidingSegmentedControl<int>(
                                          groupValue: stopBitsState.value,
                                          children: const {
                                            1: Text('1', style: TextStyle(fontSize: 10)),
                                            2: Text('2', style: TextStyle(fontSize: 10)),
                                          },
                                          onValueChanged: (val) {
                                            if (val != null) stopBitsState.value = val;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Slave ID', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(16, 16),
                                              onPressed: () => _showHelpSheet(context, 'Slave ID', 'Unique ID identifying each device on the serial bus (1-247). All devices must have unique IDs.'),
                                              child: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemTeal, size: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        CupertinoTextField(
                                          controller: slaveIdController,
                                          placeholder: '1',
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono', fontSize: 13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141419),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF23232C)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Site association selector
                        const Text('Associate with Site Folder', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                        const SizedBox(height: 6),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _showSiteAssociationPicker(context, ref, selectedSiteId);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              border: Border.all(color: const Color(0xFF2C2C35)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedSiteId.value == null
                                      ? 'No Site (Unassigned)'
                                      : siteState.sites.firstWhere(
                                          (s) => s.id == selectedSiteId.value,
                                          orElse: () => const Site(name: 'Unknown'),
                                        ).name,
                                  style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                                ),
                                const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey, size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Profile naming input
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: profileNameController,
                                placeholder: 'Save setup as profile name...',
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141419),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1F1F24)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CupertinoButton(
                              color: CupertinoColors.systemTeal.withValues(alpha:0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              borderRadius: BorderRadius.circular(8),
                              onPressed: handleSaveProfile,
                              child: const Icon(CupertinoIcons.plus, size: 14, color: CupertinoColors.systemTeal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        const Text('Preset Template', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                        const SizedBox(height: 6),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _showPresetsSheet(context, ref, ipController, portController, selectedTab, profileNameController),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              border: Border.all(color: const Color(0xFF2C2C35)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  libraryState.selectedPresetName ?? 'Choose Built-in Presets...',
                                  style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                                ),
                                const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey, size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                color: CupertinoColors.systemGrey.withValues(alpha:0.12),
                                borderRadius: BorderRadius.circular(8),
                                onPressed: () => _showImportDialog(context, ref, ipController, portController, selectedTab, profileNameController),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.square_arrow_down, size: 14, color: CupertinoColors.white),
                                    SizedBox(width: 6),
                                    Text('Import JSON', style: TextStyle(fontSize: 12, color: CupertinoColors.white)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                color: CupertinoColors.systemGrey.withValues(alpha:0.12),
                                borderRadius: BorderRadius.circular(8),
                                onPressed: () => _handleExportProfile(context, ref, profileNameController, ipController, portController, selectedTab),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.square_arrow_up, size: 14, color: CupertinoColors.white),
                                    SizedBox(width: 6),
                                    Text('Export JSON', style: TextStyle(fontSize: 12, color: CupertinoColors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        if (connState.error != null) ...[
                          Text(
                            connState.error!,
                            style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],

                        CupertinoButton(
                          color: CupertinoColors.systemTeal,
                          onPressed: connState.isConnecting ? null : handleConnect,
                          child: connState.isConnecting
                              ? const CupertinoActivityIndicator()
                              : const Text('Establish Connection', style: TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // Connection Profiles database list
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419).withValues(alpha:0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF23232C)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Site Manager Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(CupertinoIcons.square_stack_3d_up_fill, color: CupertinoColors.systemYellow, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Multi-Site Manager',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.white),
                                ),
                              ],
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showAddSiteDialog(context, ref),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemTeal.withValues(alpha:0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.plus, size: 12, color: CupertinoColors.systemTeal),
                                    SizedBox(width: 4),
                                    Text('Add Site', style: TextStyle(fontSize: 11, color: CupertinoColors.systemTeal, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Split-pane structure (using non-scrolling Column to prevent trapped scroll)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Site folders
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: Color(0xFF23232C), width: 1.0),
                                  ),
                                ),
                                padding: const EdgeInsets.only(right: 12),
                                child: siteState.isLoading
                                    ? const Center(child: CupertinoActivityIndicator())
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Special folder for all sites
                                          _buildSiteFolderItem(
                                            context,
                                            ref,
                                            title: "All Sites",
                                            description: "Show all connections",
                                            isSelected: siteState.selectedSite == null,
                                            onTap: () {
                                              ref.read(siteProvider.notifier).selectSite(null);
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          ...siteState.sites.map((site) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6.0),
                                            child: _buildSiteFolderItem(
                                              context,
                                              ref,
                                              title: site.name,
                                              description: site.description ?? "Physical Facility",
                                              isSelected: siteState.selectedSite?.id == site.id,
                                              site: site,
                                              onTap: () {
                                                ref.read(siteProvider.notifier).selectSite(site);
                                              },
                                            ),
                                          )),
                                        ],
                                      ),
                              ),
                            ),
                            
                            // Right Column: Connection cards
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.only(left: 12),
                                child: () {
                                  final filteredProfiles = siteState.selectedSite == null
                                      ? siteState.profiles
                                      : siteState.profiles.where((p) => p.siteId == siteState.selectedSite!.id).toList();
                                  
                                  if (filteredProfiles.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 24),
                                        child: Text(
                                          'No connection profiles in this site view.',
                                          style: TextStyle(
                                            color: CupertinoColors.systemGrey.withValues(alpha:0.5), 
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: filteredProfiles.map((profile) {
                                      final status = siteState.nodeStatuses[profile.id];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: _buildProfileListItem(
                                          profile,
                                          status: status,
                                          onTap: () {
                                            profileNameController.text = profile.name;
                                            selectedSiteId.value = profile.siteId;
                                            if (profile.config.protocolType == 'TCP' || profile.config.protocolType == 'RTU_TCP') {
                                              selectedTab.value = profile.config.protocolType == 'TCP' ? 0 : 1;
                                              ipController.text = profile.config.ip ?? '127.0.0.1';
                                              portController.text = (profile.config.port ?? 502).toString();
                                            } else {
                                              selectedTab.value = 2;
                                              portNameController.text = profile.config.portName ?? '/dev/ttyUSB0';
                                              baudRateController.text = (profile.config.baudRate ?? 9600).toString();
                                              parityState.value = profile.config.parity ?? 'None';
                                              dataBitsState.value = profile.config.dataBits ?? 8;
                                              stopBitsState.value = profile.config.stopBits ?? 1;
                                            }
                                          },
                                          onDelete: () => _showDeleteProfileConfirm(context, ref, profile),
                                          onConnect: () async {
                                            await connNotifier.connect(profile.config);
                                            if (ref.read(connectionProvider).isConnected) {
                                              ref.read(uiProvider.notifier).setScreen(AppScreen.registers);
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
        ),

        // Quick Actions Row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORKSTATION COMMANDS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2, letterSpacing: 1.0),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildShortcutCard(
                      icon: CupertinoIcons.antenna_radiowaves_left_right,
                      title: 'Run Network Radar',
                      desc: 'Scan subnet for slave nodes',
                      color: CupertinoColors.systemTeal,
                      onTap: () => uiNotifier.setScreen(AppScreen.scanner),
                    ),
                    const SizedBox(width: 16),
                    _buildShortcutCard(
                      icon: CupertinoIcons.play_circle_fill,
                      title: 'Mock Simulator Modbus',
                      desc: 'Spin up a virtual device',
                      color: CupertinoColors.systemPurple,
                      onTap: () => uiNotifier.setScreen(AppScreen.simulator),
                    ),
                    const SizedBox(width: 16),
                    _buildShortcutCard(
                      icon: CupertinoIcons.doc_text_fill,
                      title: 'Generate Reports',
                      desc: 'Export diagnostics & logs',
                      color: CupertinoColors.systemGreen,
                      onTap: () => uiNotifier.setScreen(AppScreen.reports),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        ),
      ],
    );
  }

  Widget _buildProfileListItem(
    ConnectionProfile profile, {
    required NodeStatus? status,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required VoidCallback onConnect,
  }) {
    String detailText = '';
    IconData icon = CupertinoIcons.bolt_horizontal_fill;
    
    if (profile.config.protocolType == 'TCP' || profile.config.protocolType == 'RTU_TCP') {
      detailText = '${profile.config.protocolType} · ${profile.config.ip}:${profile.config.port}';
      icon = CupertinoIcons.wifi;
    } else {
      detailText = '${profile.config.protocolType} · ${profile.config.portName}';
      icon = CupertinoIcons.app_badge_fill;
    }

    // Live status indicator mapping
    Color statusColor = CupertinoColors.systemGrey;
    String statusLabel = "Checking...";
    if (status != null) {
      if (status.isOnline) {
        statusColor = const Color(0xFF00E676); // High contrast bright green >= 4.5:1 on dark
        statusLabel = status.latencyMs != null ? "${status.latencyMs}ms" : "Ready";
      } else {
        statusColor = const Color(0xFFFF5252); // High contrast bright red
        statusLabel = status.statusMessage;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C35), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              minimumSize: const Size(44, 44),
              alignment: Alignment.centerLeft,
              onPressed: onTap,
              child: Row(
                children: [
                  Icon(icon, color: CupertinoColors.systemTeal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                profile.name, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CupertinoColors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11, 
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detailText, 
                          style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11, color: CupertinoColors.systemGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: onConnect,
            child: const Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.systemGreen, size: 20),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: onDelete,
            child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteFolderItem(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String description,
    required bool isSelected,
    Site? site,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? CupertinoColors.systemTeal.withValues(alpha:0.12)
            : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
              ? CupertinoColors.systemTeal.withValues(alpha:0.4)
              : const Color(0xFF2C2C35),
          width: 1.0,
        ),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(44, 44),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.folder_fill,
              color: isSelected ? CupertinoColors.systemTeal : CupertinoColors.systemGrey,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected 
                          ? CupertinoColors.systemTeal.withValues(alpha:0.8)
                          : CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (site != null) ...[
              const SizedBox(width: 4),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () => _showDeleteSiteConfirm(context, ref, site),
                child: const Icon(
                  CupertinoIcons.minus_circle,
                  color: CupertinoColors.destructiveRed,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddSiteDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Site Folder'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Site Name (e.g. Facility A)',
              style: const TextStyle(color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: descController,
              placeholder: 'Description / Location',
              style: const TextStyle(color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Create'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newSite = Site(
                  id: null,
                  name: name,
                  description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                );
                await ref.read(siteProvider.notifier).saveSite(newSite);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteSiteConfirm(BuildContext context, WidgetRef ref, Site site) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Site Folder?'),
        content: Text('Are you sure you want to delete "${site.name}"? Nodes under this site will be moved to Unassigned.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              if (site.id != null) {
                await ref.read(siteProvider.notifier).deleteSite(site.id!.toInt());
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showSiteAssociationPicker(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<int?> selectedSiteId,
  ) {
    final siteState = ref.read(siteProvider);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Associate Profile with Site'),
        message: const Text('Select a physical facility folder for this node.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              selectedSiteId.value = null;
              Navigator.pop(context);
            },
            child: const Text('No Site (Unassigned)'),
          ),
          ...siteState.sites.map((site) {
            return CupertinoActionSheetAction(
              onPressed: () {
                selectedSiteId.value = site.id!.toInt();
                Navigator.pop(context);
              },
              child: Text(site.name),
            );
          }),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }


  Widget _buildShortcutCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFF141419).withValues(alpha:0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF23232C)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CupertinoColors.white)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetsSheet(
    BuildContext context, 
    WidgetRef ref,
    TextEditingController ipController,
    TextEditingController portController,
    ValueNotifier<int> selectedTab,
    TextEditingController profileNameController,
  ) {
    final libraryNotifier = ref.read(deviceLibraryProvider.notifier);
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Built-in Device Presets'),
        message: const Text('Populate connection parameters and register tags instantly.'),
        actions: libraryNotifier.presets.map((preset) {
          return CupertinoActionSheetAction(
            onPressed: () {
              libraryNotifier.selectPreset(preset);
              
              if (preset.config.protocolType == 'TCP') {
                selectedTab.value = 0;
              } else if (preset.config.protocolType == 'RTU_TCP') {
                selectedTab.value = 1;
              } else {
                selectedTab.value = 2;
              }

              ipController.text = preset.config.ip ?? '';
              portController.text = (preset.config.port ?? 502).toString();
              profileNameController.text = preset.name;

              Navigator.pop(context);
            },
            child: Column(
              children: [
                Text(preset.name),
                Text(preset.description, style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey)),
              ],
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

  void _showImportDialog(
    BuildContext context,
    WidgetRef ref,
    TextEditingController ipController,
    TextEditingController portController,
    ValueNotifier<int> selectedTab,
    TextEditingController profileNameController,
  ) {
    final textController = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Import Profile JSON'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Paste the profile JSON schema to import connection settings and register tags:'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: textController,
              maxLines: 8,
              placeholder: '{\n  "name": "My PLC",\n  "config": { ... },\n  "tags": { ... }\n}',
              style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11, color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Import'),
            onPressed: () {
              final jsonStr = textController.text.trim();
              if (jsonStr.isEmpty) return;

              try {
                final result = ref.read(deviceLibraryProvider.notifier).importJson(jsonStr);
                if (result != null) {
                  final name = result['name'] as String;
                  final config = result['config'] as ConnectionConfig;

                  profileNameController.text = name;
                  if (config.protocolType == 'TCP') {
                    selectedTab.value = 0;
                  } else if (config.protocolType == 'RTU_TCP') {
                    selectedTab.value = 1;
                  } else {
                    selectedTab.value = 2;
                  }
                  ipController.text = config.ip ?? '';
                  portController.text = (config.port ?? 502).toString();

                  Navigator.pop(context);
                  _showToast(context, 'Profile Imported Successfully');
                } else {
                  _showToast(context, 'Invalid JSON Schema');
                }
              } on ProfileImportException catch (e) {
                _showToast(context, e.message);
              } catch (e) {
                _showToast(context, 'Error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleExportProfile(
    BuildContext context,
    WidgetRef ref,
    TextEditingController profileNameController,
    TextEditingController ipController,
    TextEditingController portController,
    ValueNotifier<int> selectedTab,
  ) {
    String protocolType = 'TCP';
    if (selectedTab.value == 1) protocolType = 'RTU_TCP';
    if (selectedTab.value == 2) protocolType = 'SERIAL';

    final config = ConnectionConfig(
      protocolType: protocolType,
      ip: ipController.text.trim().isNotEmpty ? ipController.text.trim() : null,
      port: int.tryParse(portController.text.trim()),
    );

    final name = profileNameController.text.trim().isNotEmpty 
        ? profileNameController.text.trim() 
        : 'Exported Profile';

    final jsonStr = ref.read(deviceLibraryProvider.notifier).exportPreset(name: name, config: config);
    Clipboard.setData(ClipboardData(text: jsonStr));
    _showToast(context, 'Profile JSON Copied to Clipboard');
  }

  void _showToast(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  void _showDeleteProfileConfirm(BuildContext context, WidgetRef ref, ConnectionProfile profile) {
    final connNotifier = ref.read(connectionProvider.notifier);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Connection Profile?'),
        content: Text('Are you sure you want to delete "${profile.name}"? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              if (profile.id != null) {
                await connNotifier.deleteProfile(profile.id!);
                await ref.read(siteProvider.notifier).loadAll();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.systemTeal,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context, String title, String description) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Got it'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

