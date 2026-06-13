import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';

// Import our future screens
import 'package:modbus_studio/features/hub/connection_hub_screen.dart';
import 'package:modbus_studio/features/scanner/device_scanner_screen.dart';
import 'package:modbus_studio/features/registers/register_explorer_screen.dart';
import 'package:modbus_studio/features/analyzer/protocol_analyzer_screen.dart';
import 'package:modbus_studio/features/simulator/modbus_simulator_screen.dart';
import 'package:modbus_studio/features/settings/settings_screen.dart';
import 'package:modbus_studio/features/dashboard/dashboard_screen.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/features/alarms/alarms_screen.dart';
import 'package:modbus_studio/features/reports/reports_screen.dart';
import 'package:modbus_studio/features/automation/automation_screen.dart';
import 'package:modbus_studio/features/scripting/scripting_screen.dart';



class ResponsiveNavigationShell extends HookConsumerWidget {
  const ResponsiveNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final connState = ref.watch(connectionProvider);
    
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 900;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0C), // Deep industrial dark
      child: Stack(
        children: [
          // Background ambient glows (Dynamic Design)
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getGlowColor(connState).withValues(alpha:0.12),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .blur(end: const Offset(120, 120), duration: 6.seconds)
             .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.2, 1.2), duration: 6.seconds),
          ),
          
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemPurple.withValues(alpha:0.06),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .blur(end: const Offset(90, 90), duration: 8.seconds),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Custom Header / Title Bar
                _buildTopBar(context, ref, isDesktop),
                
                // Main split layout
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Desktop Sidebar
                      if (isDesktop) _buildSidebar(context, ref),
                      
                      // Central content area
                      Expanded(
                        child: Container(
                          color: const Color(0xFF0D0D10),
                          child: _buildMainContent(uiState.currentScreen),
                        ),
                      ),
                      
                      // Right Inspector Panel
                      if (isDesktop && uiState.isInspectorOpen) _buildInspectorPanel(context, ref),
                    ],
                  ),
                ),
                
                // Bottom Status Bar
                _buildStatusBar(context, ref),
              ],
            ),
          ),
          // Alarm Slide-Down Alert Banner Overlay
          _buildAlarmOverlay(context, ref),
        ],
      ),
    );
  }

  Color _getGlowColor(ConnectionStatus status) {
    if (status.isConnecting) return CupertinoColors.systemYellow;
    if (status.isConnected) return CupertinoColors.systemTeal;
    return CupertinoColors.systemRed;
  }

  Widget _buildAlarmOverlay(BuildContext context, WidgetRef ref) {
    final alarmState = ref.watch(alarmProvider);
    final activeAlarm = alarmState.activeBannerAlarm;

    if (activeAlarm == null) return const SizedBox.shrink();

    final isCritical = activeAlarm.severity == 'Critical';
    final accentColor = isCritical ? CupertinoColors.systemRed : CupertinoColors.systemOrange;
    final backgroundColor = isCritical 
        ? CupertinoColors.systemRed.withValues(alpha:0.12)
        : CupertinoColors.systemOrange.withValues(alpha:0.12);

    return Positioned(
      top: 64,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          ref.read(alarmProvider.notifier).dismissBanner();
          ref.read(uiProvider.notifier).setScreen(AppScreen.alarms);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16161C).withValues(alpha:0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha:0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha:0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCritical ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.bell_fill,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCritical ? 'CRITICAL ALARM' : 'WARNING ALARM',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeAlarm.message,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ref.read(alarmProvider.notifier).dismissBanner();
                    },
                    child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.systemGrey, size: 18),
                  )
                ],
              ),
            ),
          ),
        ),
      ).animate().slideY(begin: -1.0, end: 0.0, duration: 400.ms, curve: Curves.easeOutCubic)
       .fadeIn(duration: 400.ms),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTopBar(BuildContext context, WidgetRef ref, bool isDesktop) {
    final uiState = ref.watch(uiProvider);
    final uiNotifier = ref.read(uiProvider.notifier);
    final connState = ref.watch(connectionProvider);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12).withValues(alpha:0.75),
        border: const Border(bottom: BorderSide(color: Color(0xFF1F1F24), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Sidebar Toggle
          Row(
            children: [
              if (isDesktop) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: uiNotifier.toggleSidebar,
                  child: Icon(
                    uiState.isSidebarCollapsed 
                        ? CupertinoIcons.sidebar_right 
                        : CupertinoIcons.sidebar_left,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                'MODBUS STUDIO',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.2,
                  color: connState.isConnected ? CupertinoColors.white : CupertinoColors.systemGrey2,
                ),
              ),
              if (connState.isConnected) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CupertinoColors.systemGreen.withValues(alpha:0.3), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connState.activeIp ?? '',
                        style: const TextStyle(
                          fontFamily: 'SF Mono',
                          fontSize: 11,
                          color: CupertinoColors.systemGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().scale(duration: 250.ms, curve: Curves.easeOutBack),
              ],
            ],
          ),

          // Center title / page label (Only on mobile/tablet if needed)
          if (!isDesktop)
            Text(
              _getScreenName(uiState.currentScreen),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),

          // Right side: Quick actions
          Row(
            children: [
              // Field Mode Toggle (Outdoor High Contrast)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: uiNotifier.toggleFieldMode,
                child: Icon(
                  uiState.isFieldMode 
                      ? CupertinoIcons.sun_max_fill 
                      : CupertinoIcons.sun_max,
                  color: uiState.isFieldMode ? CupertinoColors.systemYellow : CupertinoColors.systemGrey,
                  size: 20,
                ),
              ),
              // Inspector Toggle
              if (isDesktop)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: uiNotifier.toggleInspector,
                  child: Icon(
                    CupertinoIcons.sidebar_right,
                    color: uiState.isInspectorOpen ? CupertinoColors.systemTeal : CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    
    final double sidebarWidth = uiState.isSidebarCollapsed ? 68.0 : 230.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF121216).withValues(alpha:0.5),
            border: const Border(right: BorderSide(color: Color(0xFF1F1F24), width: 1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Main modules navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildSidebarItem(ref, AppScreen.hub, CupertinoIcons.house_alt_fill, 'Connection Hub', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.scanner, CupertinoIcons.antenna_radiowaves_left_right, 'Device Scanner', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.registers, CupertinoIcons.grid, 'Register Explorer', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.analyzer, CupertinoIcons.waveform_path_ecg, 'Protocol Analyzer', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.simulator, CupertinoIcons.play_circle_fill, 'Modbus Simulator', uiState.currentScreen),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Divider(color: Color(0xFF1F1F24), height: 1),
                    ),
                    _buildSidebarItem(ref, AppScreen.logger, CupertinoIcons.circle_grid_hex_fill, 'Data Logger (Stub)', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.charts, CupertinoIcons.chart_bar_fill, 'HMI Dashboard', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.tags, CupertinoIcons.tag_fill, 'Tag Database (Stub)', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.alarms, CupertinoIcons.alarm_fill, 'Alarm Engine (Stub)', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.scripting, CupertinoIcons.square_pencil, 'Scripting (Stub)', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.automation, CupertinoIcons.timer_fill, 'Automation Scheduler', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.reports, CupertinoIcons.doc_text_fill, 'Reports', uiState.currentScreen),
                    _buildSidebarItem(ref, AppScreen.settings, CupertinoIcons.settings_solid, 'Settings', uiState.currentScreen),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    WidgetRef ref,
    AppScreen screen,
    IconData icon,
    String label,
    AppScreen activeScreen,
  ) {
    final uiState = ref.watch(uiProvider);
    final isSelected = screen == activeScreen;
    final collapsed = uiState.isSidebarCollapsed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 10),
        onPressed: () {
          ref.read(uiProvider.notifier).setScreen(screen);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected 
                ? CupertinoColors.systemTeal.withValues(alpha:0.15)
                : CupertinoColors.transparent,
            border: isSelected 
                ? Border.all(color: CupertinoColors.systemTeal.withValues(alpha:0.25), width: 0.5) 
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? CupertinoColors.systemTeal : CupertinoColors.systemGrey,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? CupertinoColors.white : CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(AppScreen screen) {
    switch (screen) {
      case AppScreen.hub:
        return const ConnectionHubScreen();
      case AppScreen.scanner:
        return const DeviceScannerScreen();
      case AppScreen.registers:
        return const RegisterExplorerScreen();
      case AppScreen.analyzer:
        return const ProtocolAnalyzerScreen();
      case AppScreen.simulator:
        return const ModbusSimulatorScreen();
      case AppScreen.charts:
        return const DashboardScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.alarms:
        return const AlarmsScreen();
      case AppScreen.reports:
        return const ReportsScreen();
      case AppScreen.automation:
        return const AutomationScreen();
      case AppScreen.scripting:
        return const ScriptingScreen();
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.square_stack_3d_up_slash, size: 48, color: CupertinoColors.systemGrey),
              const SizedBox(height: 12),
              Text(
                '${_getScreenName(screen)} is under construction',
                style: const TextStyle(color: CupertinoColors.systemGrey),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildInspectorPanel(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionProvider);
    final connNotifier = ref.read(connectionProvider.notifier);

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF121216),
        border: Border(left: BorderSide(color: Color(0xFF1F1F24), width: 1)),
      ),
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'DEVICE INSPECTOR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.systemGrey2,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          
          if (!connState.isConnected)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.wifi_slash,
                        size: 48,
                        color: CupertinoColors.systemGrey.withValues(alpha:0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Active Connection',
                        style: TextStyle(color: CupertinoColors.systemGrey, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect to a device from the Connection Hub or scan your network to get started.',
                        style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Connected device information
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGreen.withValues(alpha:0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.device_laptop, color: CupertinoColors.systemGreen, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              connState.activeIp ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'SF Mono'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF2C2C35), height: 1),
                      const SizedBox(height: 12),
                      _buildInfoRow('Protocol', 'Modbus TCP'),
                      _buildInfoRow('Port', '502'),
                      _buildInfoRow('Status', 'Polling Active (1s)'),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        color: CupertinoColors.destructiveRed.withValues(alpha:0.2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        borderRadius: BorderRadius.circular(8),
                        onPressed: connNotifier.disconnect,
                        child: const Center(
                          child: Text(
                            'Disconnect', 
                            style: TextStyle(color: CupertinoColors.systemRed, fontSize: 13, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Add a padding space
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
          Text(value, style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionProvider);
    final uiState = ref.watch(uiProvider);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF070709),
        border: Border(top: BorderSide(color: Color(0xFF1F1F24), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Connection Status Indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connState.isConnected 
                      ? CupertinoColors.systemGreen 
                      : connState.isConnecting 
                          ? CupertinoColors.systemYellow 
                          : CupertinoColors.systemRed,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                connState.isConnected 
                    ? 'CONNECTED' 
                    : connState.isConnecting 
                        ? 'CONNECTING...' 
                        : 'DISCONNECTED',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
          
          // Center details (Field mode status, etc.)
          Row(
            children: [
              if (uiState.isFieldMode) ...[
                const Icon(CupertinoIcons.sun_max_fill, size: 11, color: CupertinoColors.systemYellow),
                const SizedBox(width: 4),
                const Text(
                  'OUTDOOR FIELD MODE ACTIVE',
                  style: TextStyle(fontSize: 10, color: CupertinoColors.systemYellow, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
              ],
              const Text(
                'DB: historian.db · WAL MODE',
                style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey2, fontFamily: 'SF Mono'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getScreenName(AppScreen screen) {
    switch (screen) {
      case AppScreen.hub:
        return 'Connection Hub';
      case AppScreen.scanner:
        return 'Device Scanner';
      case AppScreen.registers:
        return 'Register Explorer';
      case AppScreen.analyzer:
        return 'Protocol Analyzer';
      case AppScreen.logger:
        return 'Data Logger';
      case AppScreen.charts:
        return 'HMI Dashboard';
      case AppScreen.operations:
        return 'Operations';
      case AppScreen.simulator:
        return 'Modbus Simulator';
      case AppScreen.tags:
        return 'Tag Database';
      case AppScreen.alarms:
        return 'Alarm Center';
      case AppScreen.scripting:
        return 'Scripting';
      case AppScreen.reports:
        return 'Reports';
      case AppScreen.settings:
        return 'Settings';
      case AppScreen.automation:
        return 'Automation Scheduler';
    }
  }
}

// Simple Divider widget for custom layout inside ListView
class Divider extends StatelessWidget {
  final Color color;
  final double height;

  const Divider({super.key, required this.color, this.height = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color,
    );
  }
}
