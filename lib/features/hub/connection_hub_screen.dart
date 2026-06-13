import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';


class ConnectionHubScreen extends HookConsumerWidget {
  const ConnectionHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiNotifier = ref.read(uiProvider.notifier);
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final libraryState = ref.watch(deviceLibraryProvider);

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

    // Database profiles reloading trigger
    final refreshTrigger = useState<int>(0);
    final profilesFuture = useFuture(
      useMemoized(() => connNotifier.fetchProfiles(), [refreshTrigger.value]),
    );

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
      );

      await connNotifier.saveProfile(newProfile);
      profileNameController.clear();
      refreshTrigger.value++; // Trigger profile reload
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
                          const Text('IP Address', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: ipController,
                            placeholder: '192.168.1.100',
                            style: const TextStyle(color: CupertinoColors.white, fontFamily: 'SF Mono'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2C2C35)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Port', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: portController,
                                      placeholder: '502',
                                      keyboardType: TextInputType.number,
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
                                    const Text('Slave ID (Unit ID)', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: slaveIdController,
                                      placeholder: '1',
                                      keyboardType: TextInputType.number,
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
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Serial Port', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: portNameController,
                                      placeholder: '/dev/ttyUSB0 or COM1',
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
                                    const Text('Baud Rate', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: baudRateController,
                                      placeholder: '9600',
                                      keyboardType: TextInputType.number,
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
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Parity', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CupertinoSlidingSegmentedControl<String>(
                                      groupValue: parityState.value,
                                      children: const {
                                        'None': Text('None', style: TextStyle(fontSize: 11)),
                                        'Even': Text('Even', style: TextStyle(fontSize: 11)),
                                        'Odd': Text('Odd', style: TextStyle(fontSize: 11)),
                                      },
                                      onValueChanged: (val) {
                                        if (val != null) parityState.value = val;
                                      },
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
                                      keyboardType: TextInputType.number,
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
                        ],
                        const SizedBox(height: 20),

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
                  flex: 2,
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
                        Row(
                          children: [
                            const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Connection Profiles',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Profiles loader state UI
                        if (profilesFuture.connectionState == ConnectionState.waiting)
                          const Center(child: CupertinoActivityIndicator())
                        else if (profilesFuture.data == null || profilesFuture.data!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                'No saved profiles in SQLite.',
                                style: TextStyle(color: CupertinoColors.systemGrey.withValues(alpha:0.5), fontSize: 12),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 260,
                            child: ListView.builder(
                              itemCount: profilesFuture.data!.length,
                              itemBuilder: (context, index) {
                                final profile = profilesFuture.data![index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildProfileListItem(
                                    profile,
                                    onTap: () {
                                      // Populate form values
                                      profileNameController.text = profile.name;
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
                                    onDelete: () async {
                                      if (profile.id != null) {
                                        await connNotifier.deleteProfile(profile.id!);
                                        refreshTrigger.value++;
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
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
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    String detailText = '';
    IconData icon = CupertinoIcons.bolt_horizontal_fill;
    
    if (profile.config.protocolType == 'TCP' || profile.config.protocolType == 'RTU_TCP') {
      detailText = '${profile.config.protocolType} · ${profile.config.ip}:${profile.config.port}';
      icon = CupertinoIcons.wifi;
    } else {
      detailText = '${profile.config.protocolType} · ${profile.config.portName} · ${profile.config.baudRate}';
      icon = CupertinoIcons.app_badge_fill;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C35), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Row(
              children: [
                Icon(icon, color: CupertinoColors.systemTeal, size: 16),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CupertinoColors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed, size: 14),
          ),
        ],
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
}

