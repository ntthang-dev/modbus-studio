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
import 'package:modbus_studio/theme.dart';

/// Grouped collection of form controllers and value notifiers to pass
/// cleanly between the parent screen and dynamic panels.
class ConnectionFormControllers {
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController portNameController;
  final TextEditingController baudRateController;
  final TextEditingController slaveIdController;
  final TextEditingController profileNameController;
  final ValueNotifier<int> selectedTab;
  final ValueNotifier<String> parityState;
  final ValueNotifier<int> dataBitsState;
  final ValueNotifier<int> stopBitsState;
  final ValueNotifier<int?> selectedSiteId;

  ConnectionFormControllers({
    required this.ipController,
    required this.portController,
    required this.portNameController,
    required this.baudRateController,
    required this.slaveIdController,
    required this.profileNameController,
    required this.selectedTab,
    required this.parityState,
    required this.dataBitsState,
    required this.stopBitsState,
    required this.selectedSiteId,
  });
}

class ConnectionHubScreen extends HookConsumerWidget {
  const ConnectionHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Form inputs and states grouped together
    final formControllers = ConnectionFormControllers(
      ipController: useTextEditingController(text: '192.168.1.10'),
      portController: useTextEditingController(text: '502'),
      portNameController: useTextEditingController(text: '/dev/ttyUSB0'),
      baudRateController: useTextEditingController(text: '9600'),
      slaveIdController: useTextEditingController(text: '1'),
      profileNameController: useTextEditingController(text: ''),
      selectedTab: useState<int>(0),
      parityState: useState<String>('None'),
      dataBitsState: useState<int>(8),
      stopBitsState: useState<int>(1),
      selectedSiteId: useState<int?>(null),
    );

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;

    return CustomScrollView(
      slivers: [
        // System Status Header
        const SliverToBoxAdapter(
          child: SystemStatusHeader(),
        ),

        // Quick Connect Card & Favorites Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuickConnectFormPanel(formControllers: formControllers),
                      const SizedBox(height: 20),
                      SiteManagerPanel(formControllers: formControllers),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Connect Form Panel
                      Expanded(
                        flex: 3,
                        child: QuickConnectFormPanel(formControllers: formControllers),
                      ),
                      const SizedBox(width: 20),
                      // Connection Profiles database list
                      Expanded(
                        flex: 5,
                        child: SiteManagerPanel(formControllers: formControllers),
                      ),
                    ],
                  ),
          ),
        ),

        // Quick Actions Row
        const SliverToBoxAdapter(
          child: WorkstationCommandsPanel(),
        ),
      ],
    );
  }
}

class SystemStatusHeader extends ConsumerWidget {
  const SystemStatusHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSites = ref.watch(siteProvider.select((s) => s.sites.length));
    final totalProfiles = ref.watch(siteProvider.select((s) => s.profiles.length));
    final onlineNodes = ref.watch(siteProvider.select((s) => 
      s.profiles.where((p) => s.nodeStatuses[p.id]?.isOnline == true).length));
    final connState = ref.watch(connectionProvider);
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // State-mapped lighting according to the Underglow State Rule
    final Color statusColor;
    final String statusLabel;
    if (connState.isConnected) {
      statusColor = AppTheme.primaryTeal;
      statusLabel = 'CONNECTED';
    } else if (connState.isConnecting) {
      statusColor = AppTheme.cautionAmber;
      statusLabel = 'CONNECTING';
    } else if (connState.error != null) {
      statusColor = AppTheme.alertRed;
      statusLabel = 'ERROR';
    } else {
      statusColor = AppTheme.softViolet;
      statusLabel = 'IDLE';
    }

    final headerContent = Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.85, -1.0),
          radius: 2.2,
          colors: [
            statusColor.withValues(alpha: 0.08),
            statusColor.withValues(alpha: 0.02),
            CupertinoColors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  letterSpacing: 2.0,
                  fontFamily: AppTheme.fontFamilyMono,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Modbus Studio Workstation',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: CupertinoColors.white,
                  fontFamily: AppTheme.fontFamilyDisplay,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    context: context,
                    icon: CupertinoIcons.folder,
                    label: 'SITES',
                    value: '$totalSites',
                    color: CupertinoColors.systemYellow,
                    delay: 100.ms,
                    disableAnimations: disableAnimations,
                  ),
                  _buildStatChip(
                    context: context,
                    icon: CupertinoIcons.device_desktop,
                    label: 'PROFILES',
                    value: '$totalProfiles',
                    color: CupertinoColors.systemBlue,
                    delay: 150.ms,
                    disableAnimations: disableAnimations,
                  ),
                  _buildStatChip(
                    context: context,
                    icon: CupertinoIcons.checkmark_circle,
                    label: 'ONLINE',
                    value: '$onlineNodes/$totalProfiles',
                    color: CupertinoColors.systemGreen,
                    delay: 200.ms,
                    disableAnimations: disableAnimations,
                  ),
                  _buildStatChip(
                    context: context,
                    icon: CupertinoIcons.bolt,
                    label: 'SESSION',
                    value: statusLabel,
                    color: statusColor,
                    delay: 250.ms,
                    disableAnimations: disableAnimations,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return disableAnimations
        ? headerContent
        : headerContent
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Duration delay,
    required bool disableAnimations,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.systemGrey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return disableAnimations
        ? chip
        : chip
            .animate()
            .fadeIn(delay: delay, duration: 250.ms)
            .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }
}

class QuickConnectFormPanel extends HookConsumerWidget {
  final ConnectionFormControllers formControllers;

  const QuickConnectFormPanel({
    super.key,
    required this.formControllers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiNotifier = ref.read(uiProvider.notifier);
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final showAdvanced = useState(false);

    // Listeners to trigger rebuilds on form edits for real-time validation (scoped to this panel)
    final triggerRebuild = useState(0);
    useEffect(() {
      void listener() {
        triggerRebuild.value++;
      }
      formControllers.ipController.addListener(listener);
      formControllers.portController.addListener(listener);
      formControllers.portNameController.addListener(listener);
      formControllers.baudRateController.addListener(listener);
      formControllers.slaveIdController.addListener(listener);
      return () {
        formControllers.ipController.removeListener(listener);
        formControllers.portController.removeListener(listener);
        formControllers.portNameController.removeListener(listener);
        formControllers.baudRateController.removeListener(listener);
        formControllers.slaveIdController.removeListener(listener);
      };
    }, [
      formControllers.ipController,
      formControllers.portController,
      formControllers.portNameController,
      formControllers.baudRateController,
      formControllers.slaveIdController,
    ]);

    final ipText = formControllers.ipController.text.trim();
    final portText = formControllers.portController.text.trim();
    final portNameText = formControllers.portNameController.text.trim();
    final baudText = formControllers.baudRateController.text.trim();
    final slaveIdText = formControllers.slaveIdController.text.trim();

    bool isIpValid = true;
    bool isPortValid = true;
    bool isSlaveIdValid = true;
    bool isPortNameValid = true;
    bool isBaudValid = true;

    final selectedTabVal = formControllers.selectedTab.value;

    if (selectedTabVal == 0 || selectedTabVal == 1) {
      final ipRegExp = RegExp(
          r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
      isIpValid = ipRegExp.hasMatch(ipText);
      final portVal = int.tryParse(portText);
      isPortValid = portVal != null && portVal >= 1 && portVal <= 65535;
      final slaveIdVal = int.tryParse(slaveIdText);
      isSlaveIdValid = slaveIdVal != null && slaveIdVal >= 1 && slaveIdVal <= 247;
    } else {
      isPortNameValid = portNameText.isNotEmpty;
      final baudVal = int.tryParse(baudText);
      isBaudValid = baudVal != null && baudVal > 0;
      final slaveIdVal = int.tryParse(slaveIdText);
      isSlaveIdValid = slaveIdVal != null && slaveIdVal >= 1 && slaveIdVal <= 247;
    }

    final isFormValid = (selectedTabVal == 0 || selectedTabVal == 1)
        ? (isIpValid && isPortValid && isSlaveIdValid)
        : (isPortNameValid && isBaudValid && isSlaveIdValid);

    // Setup helper to connect using the active form values
    Future<void> handleConnect() async {
      final slaveId = int.tryParse(formControllers.slaveIdController.text.trim()) ?? 1;
      
      ConnectionConfig config;
      if (selectedTabVal == 0 || selectedTabVal == 1) {
        config = ConnectionConfig(
          protocolType: selectedTabVal == 0 ? 'TCP' : 'RTU_TCP',
          ip: formControllers.ipController.text.trim(),
          port: int.tryParse(formControllers.portController.text.trim()) ?? 502,
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
          portName: formControllers.portNameController.text.trim(),
          baudRate: int.tryParse(formControllers.baudRateController.text.trim()) ?? 9600,
          parity: formControllers.parityState.value,
          dataBits: formControllers.dataBitsState.value,
          stopBits: formControllers.stopBitsState.value,
        );
      }

      await connNotifier.connect(config, slaveId: slaveId);
      if (ref.read(connectionProvider).isConnected) {
        uiNotifier.setScreen(AppScreen.registers);
      }
    }

    // Save profile to database
    Future<void> handleSaveProfile() async {
      final name = formControllers.profileNameController.text.trim();
      if (name.isEmpty) return;

      ConnectionConfig config;
      if (selectedTabVal == 0 || selectedTabVal == 1) {
        config = ConnectionConfig(
          protocolType: selectedTabVal == 0 ? 'TCP' : 'RTU_TCP',
          ip: formControllers.ipController.text.trim(),
          port: int.tryParse(formControllers.portController.text.trim()) ?? 502,
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
          portName: formControllers.portNameController.text.trim(),
          baudRate: int.tryParse(formControllers.baudRateController.text.trim()) ?? 9600,
          parity: formControllers.parityState.value,
          dataBits: formControllers.dataBitsState.value,
          stopBits: formControllers.stopBitsState.value,
        );
      }

      final newProfile = ConnectionProfile(
        id: null,
        name: name,
        config: config,
        isFavorite: false,
        lastUsed: DateTime.now().millisecondsSinceEpoch,
        siteId: formControllers.selectedSiteId.value,
      );

      await connNotifier.saveProfile(newProfile);
      formControllers.profileNameController.clear();
      formControllers.selectedSiteId.value = null;
      await ref.read(siteProvider.notifier).loadAll();
      if (context.mounted) _showToast(context, 'Profile Saved Successfully');
    }

    final libraryState = ref.watch(deviceLibraryProvider);
    final siteState = ref.watch(siteProvider);
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panelBg.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.bolt_horizontal_circle_fill, color: AppTheme.primaryTeal, size: 20),
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
            groupValue: selectedTabVal,
            children: const {
              0: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('TCP/IP', style: TextStyle(fontSize: 12))),
              1: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('RTU over TCP', style: TextStyle(fontSize: 12))),
              2: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('RTU Serial', style: TextStyle(fontSize: 12))),
            },
            onValueChanged: (val) {
              if (val != null) formControllers.selectedTab.value = val;
            },
          ),
          const SizedBox(height: 20),
          
          // Dynamic parameters form (animated tab transition)
          AnimatedSwitcher(
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: (selectedTabVal == 0 || selectedTabVal == 1)
                ? _buildFormGroup(
                    key: const ValueKey('form_network_settings'),
                    title: 'Network Settings',
                    children: [
                      const Text('IP Address', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: formControllers.ipController,
                        placeholder: '192.168.1.100',
                        placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.panelBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isIpValid ? AppTheme.borderMedium : AppTheme.alertRed,
                            width: isIpValid ? 1.0 : 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      if (!isIpValid && ipText.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Invalid IPv4 format (e.g. 192.168.1.100)',
                            style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
                          ),
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
                                  controller: formControllers.portController,
                                  placeholder: '502',
                                  placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                                  decoration: BoxDecoration(
                                    color: AppTheme.panelBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPortValid ? AppTheme.borderMedium : AppTheme.alertRed,
                                      width: isPortValid ? 1.0 : 1.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                if (!isPortValid && portText.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Port: 1 - 65535',
                                      style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Slave ID (Unit ID)', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(16, 16),
                                      onPressed: () => _showHelpSheet(context, 'Slave ID', 'The Modbus address of the device (1-247). Unit ID is used in TCP encapsulation to route requests.'),
                                      child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                CupertinoTextField(
                                  controller: formControllers.slaveIdController,
                                  placeholder: '1',
                                  placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                                  decoration: BoxDecoration(
                                    color: AppTheme.panelBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSlaveIdValid ? AppTheme.borderMedium : AppTheme.alertRed,
                                      width: isSlaveIdValid ? 1.0 : 1.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                if (!isSlaveIdValid && slaveIdText.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'ID: 1 - 247',
                                      style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('form_serial_settings'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                      controller: formControllers.portNameController,
                                      placeholder: '/dev/ttyUSB0 or COM1',
                                      placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                                      style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                                      decoration: BoxDecoration(
                                        color: AppTheme.panelBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isPortNameValid ? AppTheme.borderMedium : AppTheme.alertRed,
                                          width: isPortNameValid ? 1.0 : 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    if (!isPortNameValid && portNameText.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Required',
                                          style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Baud Rate', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(16, 16),
                                          onPressed: () => _showHelpSheet(context, 'Baud Rate', 'The speed of communication over the serial link in bits per second (e.g. 9600, 19200, 115200). Must match device config.'),
                                          child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: formControllers.baudRateController,
                                      placeholder: '9600',
                                      placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                                      decoration: BoxDecoration(
                                        color: AppTheme.panelBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isBaudValid ? AppTheme.borderMedium : AppTheme.alertRed,
                                          width: isBaudValid ? 1.0 : 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    if (!isBaudValid && baudText.isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Baud rate required',
                                          style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
                                        ),
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
                                          child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    CupertinoSlidingSegmentedControl<String>(
                                      groupValue: formControllers.parityState.value,
                                      children: const {
                                        'None': Text('None', style: TextStyle(fontSize: 10)),
                                        'Even': Text('Even', style: TextStyle(fontSize: 10)),
                                        'Odd': Text('Odd', style: TextStyle(fontSize: 10)),
                                      },
                                      onValueChanged: (val) {
                                        if (val != null) formControllers.parityState.value = val;
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
                                          child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    CupertinoSlidingSegmentedControl<int>(
                                      groupValue: formControllers.dataBitsState.value,
                                      children: const {
                                        7: Text('7', style: TextStyle(fontSize: 10)),
                                        8: Text('8', style: TextStyle(fontSize: 10)),
                                      },
                                      onValueChanged: (val) {
                                        if (val != null) formControllers.dataBitsState.value = val;
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
                                          child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    CupertinoSlidingSegmentedControl<int>(
                                      groupValue: formControllers.stopBitsState.value,
                                      children: const {
                                        1: Text('1', style: TextStyle(fontSize: 10)),
                                        2: Text('2', style: TextStyle(fontSize: 10)),
                                      },
                                      onValueChanged: (val) {
                                        if (val != null) formControllers.stopBitsState.value = val;
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
                                          child: const Icon(CupertinoIcons.question_circle, color: AppTheme.primaryTeal, size: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    CupertinoTextField(
                                      controller: formControllers.slaveIdController,
                                      placeholder: '1',
                                      placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13, fontFamily: AppTheme.fontFamilyMono),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      style: const TextStyle(color: CupertinoColors.white, fontFamily: AppTheme.fontFamilyMono, fontSize: 13),
                                      decoration: BoxDecoration(
                                        color: AppTheme.panelBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSlaveIdValid ? AppTheme.borderMedium : AppTheme.alertRed,
                                          width: isSlaveIdValid ? 1.0 : 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    if (!isSlaveIdValid && slaveIdText.isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'ID: 1 - 247',
                                          style: TextStyle(color: AppTheme.alertRed, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Site association selector
          const Text('Associate with Site Folder', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
          const SizedBox(height: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              _showSiteAssociationPicker(context, ref, formControllers.selectedSiteId);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formControllers.selectedSiteId.value == null
                        ? 'No Site (Unassigned)'
                        : siteState.sites.firstWhere(
                            (s) => s.id == formControllers.selectedSiteId.value,
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
                  controller: formControllers.profileNameController,
                  placeholder: 'Save setup as profile name...',
                  placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.panelBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                color: isFormValid
                    ? AppTheme.primaryTeal.withValues(alpha:0.15)
                    : CupertinoColors.systemGrey.withValues(alpha:0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: BorderRadius.circular(8),
                onPressed: isFormValid ? handleSaveProfile : null,
                child: Icon(
                  CupertinoIcons.plus,
                  size: 14,
                  color: isFormValid ? AppTheme.primaryTeal : CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Advanced Options Toggle Button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => showAdvanced.value = !showAdvanced.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  showAdvanced.value ? 'Hide Advanced Options' : 'Show Advanced Options',
                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Icon(
                  showAdvanced.value ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 10,
                  color: AppTheme.primaryTeal,
                ),
              ],
            ),
          ),
          
          AnimatedSwitcher(
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: child,
                ),
              );
            },
            child: showAdvanced.value
                ? Padding(
                    key: const ValueKey('advanced_settings_visible'),
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Preset Template', style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12)),
                        const SizedBox(height: 6),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _showPresetsSheet(
                            context, 
                            ref, 
                            formControllers.ipController, 
                            formControllers.portController, 
                            formControllers.selectedTab, 
                            formControllers.profileNameController,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              border: Border.all(color: AppTheme.borderLight),
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
                                onPressed: () => _showImportDialog(
                                  context, 
                                  ref, 
                                  formControllers.ipController, 
                                  formControllers.portController, 
                                  formControllers.selectedTab, 
                                  formControllers.profileNameController,
                                ),
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
                                onPressed: () => _handleExportProfile(
                                  context, 
                                  ref, 
                                  formControllers.profileNameController, 
                                  formControllers.ipController, 
                                  formControllers.portController, 
                                  formControllers.selectedTab,
                                ),
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
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('advanced_settings_hidden')),
          ),
          const SizedBox(height: 24),
          
          AnimatedSwitcher(
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: child,
                ),
              );
            },
            child: connState.error != null
                ? Container(
                    key: const ValueKey('conn_error_panel'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.alertRed.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.alertRed.withValues(alpha:0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppTheme.alertRed, size: 14),
                            const SizedBox(width: 6),
                            const Text(
                              'Connection Failed',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CupertinoColors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          connState.error!,
                          style: TextStyle(color: AppTheme.alertRed.withValues(alpha:0.95), fontSize: 11, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 0.5, color: AppTheme.borderLight),
                        const SizedBox(height: 8),
                        const Text(
                          'Troubleshooting Tips:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: CupertinoColors.systemGrey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Verify physical ethernet/serial connection.\n• Check if the device Slave ID (Unit ID) matches.\n• Subnet mismatch? Try scanning the network subnet.',
                          style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => uiNotifier.setScreen(AppScreen.scanner),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Run Network Radar',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                              ),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.arrow_right, size: 10, color: AppTheme.primaryTeal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('conn_error_empty')),
          ),

          CupertinoButton(
            color: isFormValid ? AppTheme.primaryTeal : CupertinoColors.systemGrey.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(8),
            onPressed: (connState.isConnecting || !isFormValid) ? null : handleConnect,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: connState.isConnecting
                  ? const CupertinoActivityIndicator(
                      key: ValueKey('connecting_spinner'),
                      color: CupertinoColors.white,
                    )
                  : Row(
                      key: const ValueKey('connect_button_content'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.bolt_fill,
                          size: 16,
                          color: isFormValid ? CupertinoColors.white : CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Establish Connection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isFormValid ? CupertinoColors.white : CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormGroup({
    Key? key,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTeal,
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
              placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 11, fontFamily: AppTheme.fontFamilyMono),
              style: const TextStyle(fontFamily: AppTheme.fontFamilyMono, fontSize: 11, color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
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
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 24,
        right: 24,
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withValues(alpha:0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha:0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.checkmark_circle_fill, color: AppTheme.primaryTeal, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}

class SiteManagerPanel extends HookConsumerWidget {
  final ConnectionFormControllers formControllers;

  const SiteManagerPanel({
    super.key,
    required this.formControllers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteState = ref.watch(siteProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;
    final searchQuery = useState('');
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final siteFoldersList = AnimatedSwitcher(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: siteState.isLoading
          ? const Center(
              key: ValueKey('sites_loading'),
              child: CupertinoActivityIndicator(),
            )
          : Column(
              key: const ValueKey('sites_list'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SiteFolderItem(
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
                  child: SiteFolderItem(
                    title: site.name,
                    description: site.description ?? "Physical Facility",
                    isSelected: siteState.selectedSite?.id == site.id,
                    site: site,
                    onTap: () {
                      ref.read(siteProvider.notifier).selectSite(site);
                    },
                    onDelete: () => _showDeleteSiteConfirm(context, ref, site),
                  ),
                )),
              ],
            ),
    );

    final connectionCardsList = AnimatedSwitcher(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: () {
        final filteredProfiles = siteState.selectedSite == null
            ? siteState.profiles
            : siteState.profiles.where((p) => p.siteId == siteState.selectedSite!.id).toList();

        final query = searchQuery.value.toLowerCase().trim();
        final searchedProfiles = query.isEmpty
            ? filteredProfiles
            : filteredProfiles.where((p) => 
                p.name.toLowerCase().contains(query) || 
                (p.config.ip?.contains(query) ?? false) ||
                (p.config.portName?.toLowerCase().contains(query) ?? false)
              ).toList();
        
        if (searchedProfiles.isEmpty) {
          return Center(
            key: ValueKey('profiles_empty_${siteState.selectedSite?.id ?? "all"}_$query'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                query.isEmpty
                    ? 'No connection profiles in this site view.'
                    : 'No matching connection profiles.',
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
          key: ValueKey('profiles_list_${siteState.selectedSite?.id ?? "all"}_$query'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: searchedProfiles.map((profile) {
            final status = siteState.nodeStatuses[profile.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ProfileListItem(
                profile: profile,
                status: status,
                onTap: () {
                  formControllers.profileNameController.text = profile.name;
                  formControllers.selectedSiteId.value = profile.siteId;
                  if (profile.config.protocolType == 'TCP' || profile.config.protocolType == 'RTU_TCP') {
                    formControllers.selectedTab.value = profile.config.protocolType == 'TCP' ? 0 : 1;
                    formControllers.ipController.text = profile.config.ip ?? '127.0.0.1';
                    formControllers.portController.text = (profile.config.port ?? 502).toString();
                  } else {
                    formControllers.selectedTab.value = 2;
                    formControllers.portNameController.text = profile.config.portName ?? '/dev/ttyUSB0';
                    formControllers.baudRateController.text = (profile.config.baudRate ?? 9600).toString();
                    formControllers.parityState.value = profile.config.parity ?? 'None';
                    formControllers.dataBitsState.value = profile.config.dataBits ?? 8;
                    formControllers.stopBitsState.value = profile.config.stopBits ?? 1;
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
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panelBg.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderMedium),
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
                    color: AppTheme.primaryTeal.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.plus, size: 12, color: AppTheme.primaryTeal),
                      SizedBox(width: 4),
                      Text('Add Site', style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    siteFoldersList,
                    const SizedBox(height: 16),
                    CupertinoSearchTextField(
                      placeholder: 'Search profiles...',
                      placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13),
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                      onChanged: (val) {
                        searchQuery.value = val;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Profiles',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CupertinoColors.systemGrey),
                    ),
                    const SizedBox(height: 8),
                    connectionCardsList,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Site folders
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppTheme.borderMedium, width: 1.0),
                          ),
                        ),
                        padding: const EdgeInsets.only(right: 12),
                        child: siteFoldersList,
                      ),
                    ),
                    
                    // Right Column: Connection cards
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CupertinoSearchTextField(
                              placeholder: 'Search profiles...',
                              placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13),
                              style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                              onChanged: (val) {
                                searchQuery.value = val;
                              },
                            ),
                            const SizedBox(height: 12),
                            connectionCardsList,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class ProfileListItem extends StatefulWidget {
  final ConnectionProfile profile;
  final NodeStatus? status;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onConnect;

  const ProfileListItem({
    super.key,
    required this.profile,
    required this.status,
    required this.onTap,
    required this.onDelete,
    required this.onConnect,
  });

  @override
  State<ProfileListItem> createState() => _ProfileListItemState();
}

class _ProfileListItemState extends State<ProfileListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String detailText = '';
    IconData icon = CupertinoIcons.bolt_horizontal_fill;
    
    if (widget.profile.config.protocolType == 'TCP' || widget.profile.config.protocolType == 'RTU_TCP') {
      detailText = '${widget.profile.config.protocolType} · ${widget.profile.config.ip}:${widget.profile.config.port}';
      icon = CupertinoIcons.wifi;
    } else {
      detailText = '${widget.profile.config.protocolType} · ${widget.profile.config.portName}';
      icon = CupertinoIcons.app_badge_fill;
    }

    Color statusColor = CupertinoColors.systemGrey;
    String statusLabel = "Checking...";
    if (widget.status != null) {
      if (widget.status!.isOnline) {
        statusColor = AppTheme.operationalGreen;
        statusLabel = widget.status!.latencyMs != null ? "${widget.status!.latencyMs}ms" : "Ready";
      } else {
        statusColor = AppTheme.alertRed;
        statusLabel = widget.status!.statusMessage;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered ? AppTheme.cardBg.withValues(alpha: 0.9) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered ? AppTheme.primaryTeal.withValues(alpha: 0.3) : AppTheme.borderLight, 
            width: 0.5
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Connection profile: ${widget.profile.name}. Status: $statusLabel. Configuration: $detailText.',
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerLeft,
                  onPressed: widget.onTap,
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.primaryTeal, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.profile.name, 
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
                              style: const TextStyle(fontFamily: AppTheme.fontFamilyMono, fontSize: 11, color: CupertinoColors.systemGrey),
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
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Connect to profile ${widget.profile.name}',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: widget.onConnect,
                child: const Icon(CupertinoIcons.play_circle_fill, color: AppTheme.operationalGreen, size: 20),
              ),
            ),
            Semantics(
              button: true,
              label: 'Delete connection profile ${widget.profile.name}',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: widget.onDelete,
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SiteFolderItem extends StatefulWidget {
  final String title;
  final String description;
  final bool isSelected;
  final Site? site;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SiteFolderItem({
    super.key,
    required this.title,
    required this.description,
    required this.isSelected,
    this.site,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<SiteFolderItem> createState() => _SiteFolderItemState();
}

class _SiteFolderItemState extends State<SiteFolderItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primaryTeal;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (_isHovered ? AppTheme.cardBg.withValues(alpha: 0.8) : AppTheme.cardBg),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSelected
                ? activeColor.withValues(alpha: 0.5)
                : (_isHovered ? activeColor.withValues(alpha: 0.2) : AppTheme.borderLight),
            width: 1.0,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: -1,
                  )
                ]
              : [],
        ),
        child: Semantics(
          button: true,
          selected: widget.isSelected,
          label: 'Site folder: ${widget.title}. ${widget.description}.',
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(44, 44),
            onPressed: widget.onTap,
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.folder_fill,
                  color: widget.isSelected ? activeColor : const Color(0xFF9B9B9F),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: widget.isSelected ? CupertinoColors.white : const Color(0xFF9B9B9F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isSelected 
                              ? activeColor.withValues(alpha: 0.8)
                              : const Color(0xFF9B9B9F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.site != null && widget.onDelete != null) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Delete site folder ${widget.title}',
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: widget.onDelete,
                      child: const Icon(
                        CupertinoIcons.minus_circle,
                        color: CupertinoColors.destructiveRed,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

  void _showAddSiteDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Create Site Folder'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Site Name (e.g. Facility A)',
              placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13),
              style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: descController,
              placeholder: 'Description / Location',
              placeholderStyle: const TextStyle(color: Color(0xFF7C7C82), fontSize: 13),
              style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
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
            child: const Text('Create Folder'),
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              Navigator.pop(context);
              if (name.isNotEmpty) {
                final newSite = Site(
                  id: null,
                  name: name,
                  description: desc.isNotEmpty ? desc : null,
                );
                await ref.read(siteProvider.notifier).saveSite(newSite);
              }
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
            child: const Text('Keep Folder'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete Folder'),
            onPressed: () async {
              final id = site.id;
              Navigator.pop(context);
              if (id != null) {
                await ref.read(siteProvider.notifier).deleteSite(id.toInt());
              }
            },
          ),
        ],
      ),
    );
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
            child: const Text('Keep Profile'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete Profile'),
            onPressed: () async {
              final id = profile.id;
              Navigator.pop(context);
              if (id != null) {
                await connNotifier.deleteProfile(id);
                await ref.read(siteProvider.notifier).loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

class WorkstationCommandsPanel extends ConsumerWidget {
  const WorkstationCommandsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiNotifier = ref.read(uiProvider.notifier);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final panel = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORKSTATION COMMANDS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.systemGrey2,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          isCompact
              ? Column(
                  children: [
                    ShortcutCard(
                      icon: CupertinoIcons.antenna_radiowaves_left_right,
                      title: 'Run Network Radar',
                      desc: 'Scan subnet for slave nodes',
                      color: AppTheme.primaryTeal,
                      onTap: () => uiNotifier.setScreen(AppScreen.scanner),
                    ),
                    const SizedBox(height: 12),
                    ShortcutCard(
                      icon: CupertinoIcons.play_circle_fill,
                      title: 'Mock Simulator Modbus',
                      desc: 'Spin up a virtual device',
                      color: AppTheme.softViolet,
                      onTap: () => uiNotifier.setScreen(AppScreen.simulator),
                    ),
                    const SizedBox(height: 12),
                    ShortcutCard(
                      icon: CupertinoIcons.doc_text_fill,
                      title: 'Generate Reports',
                      desc: 'Export diagnostics & logs',
                      color: AppTheme.operationalGreen,
                      onTap: () => uiNotifier.setScreen(AppScreen.reports),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: ShortcutCard(
                        icon: CupertinoIcons.antenna_radiowaves_left_right,
                        title: 'Run Network Radar',
                        desc: 'Scan subnet for slave nodes',
                        color: AppTheme.primaryTeal,
                        onTap: () => uiNotifier.setScreen(AppScreen.scanner),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ShortcutCard(
                        icon: CupertinoIcons.play_circle_fill,
                        title: 'Mock Simulator Modbus',
                        desc: 'Spin up a virtual device',
                        color: AppTheme.softViolet,
                        onTap: () => uiNotifier.setScreen(AppScreen.simulator),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ShortcutCard(
                        icon: CupertinoIcons.doc_text_fill,
                        title: 'Generate Reports',
                        desc: 'Export diagnostics & logs',
                        color: AppTheme.operationalGreen,
                        onTap: () => uiNotifier.setScreen(AppScreen.reports),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );

    return disableAnimations
        ? panel
        : panel.animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class ShortcutCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const ShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 110,
            decoration: BoxDecoration(
              color: _isHovered 
                  ? AppTheme.cardBg
                  : AppTheme.panelBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered 
                    ? widget.color.withValues(alpha: 0.6) 
                    : AppTheme.borderMedium,
                width: _isHovered ? 1.0 : 0.5,
              ),
              boxShadow: _isHovered 
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: -2,
                      )
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedRotation(
                  turns: _isHovered ? 0.03 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CupertinoColors.white)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.desc, 
                      style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
