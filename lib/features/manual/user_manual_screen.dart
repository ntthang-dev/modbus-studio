import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';

enum ManualSection {
  gettingStarted,
  modbusBasics,
  scripting,
  changelog,
  copyright,
}

class UserManualScreen extends HookConsumerWidget {
  const UserManualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final bool isField = uiState.isFieldMode;
    
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0D0D10);
    final Color cardColor = isField ? CupertinoColors.white : const Color(0xFF16161C);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;
    final Color subtitleColor = isField ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final Color borderColor = isField ? CupertinoColors.systemGrey4 : const Color(0xFF2C2C35);

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 900;

    final activeSection = useState(ManualSection.gettingStarted);

    Widget buildSubMenu() {
      return Container(
        width: 220,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: borderColor, width: 1)),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          children: [
            _buildSubMenuItem(
              title: 'Getting Started',
              icon: CupertinoIcons.play_circle_fill,
              section: ManualSection.gettingStarted,
              activeSection: activeSection.value,
              onTap: () => activeSection.value = ManualSection.gettingStarted,
              isField: isField,
            ),
            _buildSubMenuItem(
              title: 'Modbus Basics',
              icon: CupertinoIcons.waveform,
              section: ManualSection.modbusBasics,
              activeSection: activeSection.value,
              onTap: () => activeSection.value = ManualSection.modbusBasics,
              isField: isField,
            ),
            _buildSubMenuItem(
              title: 'Scripting Engine',
              icon: CupertinoIcons.square_pencil_fill,
              section: ManualSection.scripting,
              activeSection: activeSection.value,
              onTap: () => activeSection.value = ManualSection.scripting,
              isField: isField,
            ),
            _buildSubMenuItem(
              title: 'Changelog',
              icon: CupertinoIcons.doc_text_fill,
              section: ManualSection.changelog,
              activeSection: activeSection.value,
              onTap: () => activeSection.value = ManualSection.changelog,
              isField: isField,
            ),
            _buildSubMenuItem(
              title: 'Copyright & License',
              icon: CupertinoIcons.info_circle_fill,
              section: ManualSection.copyright,
              activeSection: activeSection.value,
              onTap: () => activeSection.value = ManualSection.copyright,
              isField: isField,
            ),
          ],
        ),
      );
    }

    Widget buildContent() {
      return Expanded(
        child: Container(
          color: backgroundColor,
          padding: const EdgeInsets.all(24.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildSectionContent(activeSection.value, textColor, subtitleColor, isField),
              ),
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildSubMenu(),
                buildContent(),
              ],
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CupertinoSlidingSegmentedControl<ManualSection>(
                      groupValue: activeSection.value,
                      onValueChanged: (val) {
                        if (val != null) {
                          activeSection.value = val;
                        }
                      },
                      children: const {
                        ManualSection.gettingStarted: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('Start', style: TextStyle(fontSize: 12)),
                        ),
                        ManualSection.modbusBasics: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('Modbus', style: TextStyle(fontSize: 12)),
                        ),
                        ManualSection.scripting: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('Script', style: TextStyle(fontSize: 12)),
                        ),
                        ManualSection.changelog: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('Changelog', style: TextStyle(fontSize: 12)),
                        ),
                        ManualSection.copyright: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('Copyright', style: TextStyle(fontSize: 12)),
                        ),
                      },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildSectionContent(activeSection.value, textColor, subtitleColor, isField),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubMenuItem({
    required String title,
    required IconData icon,
    required ManualSection section,
    required ManualSection activeSection,
    required VoidCallback onTap,
    required bool isField,
  }) {
    final isSelected = section == activeSection;
    final Color activeColor = isField ? CupertinoColors.systemTeal : CupertinoColors.systemTeal;
    final Color inactiveColor = isField ? CupertinoColors.black : CupertinoColors.systemGrey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onPressed: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : CupertinoColors.transparent,
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.25), width: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? (isField ? CupertinoColors.black : CupertinoColors.white)
                        : inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(
    ManualSection section,
    Color textColor,
    Color subtitleColor,
    bool isField,
  ) {
    switch (section) {
      case ManualSection.gettingStarted:
        return _buildGettingStarted(textColor, subtitleColor, isField);
      case ManualSection.modbusBasics:
        return _buildModbusBasics(textColor, subtitleColor, isField);
      case ManualSection.scripting:
        return _buildScriptingEngine(textColor, subtitleColor, isField);
      case ManualSection.changelog:
        return _buildChangelog(textColor, subtitleColor, isField);
      case ManualSection.copyright:
        return _buildCopyright(textColor, subtitleColor, isField);
    }
  }

  // --- CONTENT SECTION BUILDERS ---

  Widget _buildGettingStarted(Color textColor, Color subtitleColor, bool isField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Getting Started', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Text(
          'Welcome to Modbus Studio. This application provides a modern graphical SCADA workstation interface for managing Modbus-compatible telemetry networks.',
          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        ),
        const SizedBox(height: 20),
        _buildStepItem('1', 'Create a Connection Profile',
            'Navigate to the Connection Hub. Add a profile folder representing your industrial site, then configure TCP/IP parameters (IP Address, Port) or Serial/RTU settings (COM port path, Baud Rate, Parity, Stop bits).', textColor),
        _buildStepItem('2', 'Define Register Poll Ranges',
            'Go to the Register Explorer. At the top configuration card, choose the function code (FC01–FC04), starting address, and quantity. Tap Poll to start reading telemetry in real-time.', textColor),
        _buildStepItem('3', 'Customize Scaling & Formatting',
            'On individual register tiles, tap the settings cog. You can select display formatting (e.g. Hex, Binary, Float32) and configure linear scaling parameters (multiplier, offset, suffix unit).', textColor),
        _buildStepItem('4', 'Create HMI Dashboard Widgets',
            'Drag-and-drop gauges, status lamps, dials, and switch components onto the workspace in the HMI Dashboard to build real-time operators decks.', textColor),
      ],
    );
  }

  Widget _buildModbusBasics(Color textColor, Color subtitleColor, bool isField) {
    final Color sectionTitleColor = isField ? CupertinoColors.black : CupertinoColors.systemTeal;
    final Color compareHeaderColor = isField ? CupertinoColors.systemGrey5 : const Color(0xFF23232C);
    final Color compareRowColor = isField ? CupertinoColors.white : const Color(0xFF16161C);
    final Color borderColor = isField ? CupertinoColors.systemGrey4 : const Color(0xFF2C2C35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modbus Protocol Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Text(
          'Modbus is an open-source industrial communication protocol originally developed by Modicon (now Schneider Electric) in 1979. It remains the most widely used protocol for connecting industrial electronic devices such as PLCs, RTUs, sensors, and actuators.',
          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        ),
        const SizedBox(height: 20),
        
        Text('Core Concepts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 8),
        _buildBulletPoint('Query-Response Model', 'Only the master (client) can initiate queries. Slaves (servers) listen for requests and respond with data or acknowledgment.', textColor),
        _buildBulletPoint('PDU & ADU', 'The Protocol Data Unit (PDU) contains the Function Code and Data. The Application Data Unit (ADU) wraps the PDU with transport-specific headers/checksums.', textColor),
        
        const SizedBox(height: 24),
        Text('Modbus RTU (Serial)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 8),
        Text(
          'Modbus RTU transmits data as compact binary bytes over serial communication lines (most commonly RS-485 or RS-232). It is simple, highly robust over long distances in noisy factory environments, and requires low overhead.',
          style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4),
        ),
        const SizedBox(height: 10),
        _buildBulletPoint('CRC Error Detection', 'Every RTU packet ends with a 16-bit Cyclic Redundancy Check (CRC) checksum. If the receiver calculates a different CRC, the corrupted frame is discarded.', textColor),
        _buildBulletPoint('Timing Constraints', 'RTU frames are separated by a silent interval of at least 3.5 character times. Precise timing is required to prevent frame fragmentation.', textColor),

        const SizedBox(height: 24),
        Text('Modbus TCP (Ethernet)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 8),
        Text(
          'Modbus TCP encapsulates standard Modbus query frames inside TCP/IP packets. It runs over standard Ethernet networks, typically utilizing TCP port 502.',
          style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4),
        ),
        const SizedBox(height: 10),
        _buildBulletPoint('MBAP Header', 'A 7-byte Modbus Application Protocol (MBAP) header is prepended to the frame, containing Transaction ID, Protocol ID, Length, and Unit ID.', textColor),
        _buildBulletPoint('Unit ID (Bridge)', 'The Slave ID field becomes the Unit ID. While mostly unused on direct Ethernet devices, it is critical for routing messages through TCP-to-RTU gateways.', textColor),

        const SizedBox(height: 24),
        Text('Protocol Comparison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildCompareHeader(compareHeaderColor, textColor, borderColor),
              _buildCompareRow('Medium', 'Serial (RS-485, RS-232)', 'Ethernet / Wi-Fi', compareRowColor, textColor, borderColor),
              _buildCompareRow('Speed', '9600 - 115200 bps', '10/100/1000 Mbps', compareRowColor, textColor, borderColor),
              _buildCompareRow('Error Check', '16-bit CRC', 'TCP/IP Checksum', compareRowColor, textColor, borderColor),
              _buildCompareRow('Topology', 'Daisy-chain / bus', 'Star / network switch', compareRowColor, textColor, borderColor),
              _buildCompareRow('Max Nodes', '247 devices', 'Virtually unlimited', compareRowColor, textColor, borderColor),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text('Core Memory Blocks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 12),
        _buildBasicsCard('Coils (FC01)', 'Read / Write', 'Single-bit binary states (discrete outputs). Used for relays, solenoid valves, and power switches.', textColor, isField),
        _buildBasicsCard('Discrete Inputs (FC02)', 'Read-Only', 'Single-bit binary states (discrete inputs). Used for limit switches, proximity sensors, and status signals.', textColor, isField),
        _buildBasicsCard('Holding Registers (FC03)', 'Read / Write', '16-bit analog registers. Used for configuration parameters, setpoints, and analog control outputs.', textColor, isField),
        _buildBasicsCard('Input Registers (FC04)', 'Read-Only', '16-bit analog registers. Used for sensor measurements, telemetry metrics, and status words.', textColor, isField),
      ],
    );
  }

  Widget _buildScriptingEngine(Color textColor, Color subtitleColor, bool isField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Embedded Scripting Engine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Text(
          'Modbus Studio includes a sandboxed QuickJS JavaScript engine. This allows developers to run automation sequences or check logic thresholds against live Modbus inputs.',
          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text('Available Global Methods:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subtitleColor)),
        const SizedBox(height: 8),
        _buildCodeBlock('''
// Read value at address (0-indexed)
const temp = getRegister(30001);

// Write value to holding register
setRegister(40002, 1);

// Log message to the Script Console
log("Temperature read: " + temp);

// Trigger a system alarm rule
logAlarm("Critical", "High temperature threshold exceeded!");
''', isField),
        const SizedBox(height: 12),
        Text(
          'Security Sandbox Rule: Scripts are strictly local and cannot access the workstation filesystem or execute network requests.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.systemOrange),
        ),
      ],
    );
  }

  Widget _buildChangelog(Color textColor, Color subtitleColor, bool isField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Changelog', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 16),
        _buildReleaseItem('v1.1.0 (Current Release)', '2026-06-14', [
          'Added multi-type polling for Coils (FC01), Discrete Inputs (FC02), and Input Registers (FC04).',
          'Implemented a dynamic poll range config header inside Register Explorer.',
          'Added per-register data formatting options (Int16, Uint16, Int32, Uint32, Float32, Hex, Binary, Boolean).',
          'Introduced custom linear scaling (multiplier, offset, unit suffix) with SQLite persistence.',
        ], textColor),
        const SizedBox(height: 16),
        _buildReleaseItem('v1.0.1', '2026-06-14', [
          'Migrated Connection Hub to the premium Liquid Control Deck design system.',
          'Refactored spacing and inputs to exceed 48x48dp for field/tablet touch compliance.',
          'Stabilized animation pumps in the automated widget testing suite.',
        ], textColor),
        const SizedBox(height: 16),
        _buildReleaseItem('v1.0.0', '2026-06-14', [
          'Initial launch of Modbus Studio SCADA Workstation.',
          'Added sandboxed QuickJS automation scripting capabilities.',
          'Configured Alarms Engine database logging and telemetry logs tables.',
          'Implemented drag-and-drop HMI dashboard layout and widgets canvas.',
        ], textColor),
      ],
    );
  }

  Widget _buildCopyright(Color textColor, Color subtitleColor, bool isField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Copyright & Licensing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isField ? CupertinoColors.systemGrey6 : const Color(0xFF23232C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isField ? CupertinoColors.systemGrey4 : const Color(0xFF33333F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '© 2026 ntthang-dev (ぞたの). All rights reserved.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              Text(
                'This application software, code architecture, and related visual designs are proprietary. Permission is hereby granted to any person obtaining a copy of this software to use the workstation interface for industrial monitoring purposes, subject to the following conditions:',
                style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• The original copyright notice and developer attribution "ntthang-dev (ぞたの)" must be preserved in all copies or substantial portions of the Software.', style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
                    const SizedBox(height: 6),
                    Text('• Commercial distribution or white-labeling of the compiled binaries without prior written consent from the author is strictly prohibited.', style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
                style: TextStyle(fontSize: 11, color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SUB-WIDGET UTILITIES ---

  Widget _buildStepItem(String step, String title, String desc, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: CupertinoColors.systemTeal,
              shape: BoxShape.circle,
            ),
            child: Text(step, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBasicsCard(String title, String access, String desc, Color textColor, bool isField) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isField ? CupertinoColors.systemGrey6 : const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isField ? CupertinoColors.systemGrey4 : const Color(0xFF2E2E38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemTeal.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(access, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemTeal, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String code, bool isField) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isField ? CupertinoColors.systemGrey5 : const Color(0xFF070709),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isField ? CupertinoColors.systemGrey4 : const Color(0xFF222228)),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'SF Mono',
          fontSize: 12,
          color: isField ? CupertinoColors.black : const Color(0xFF00FFCC),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildReleaseItem(String version, String date, List<String> bulletPoints, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(version, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            Text(date, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bulletPoints
                .map((bp) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: CupertinoColors.systemTeal)),
                          Expanded(child: Text(bp, style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, height: 1.3))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        )
      ],
    );
  }

  Widget _buildBulletPoint(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: CupertinoColors.systemTeal, fontSize: 14)),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareHeader(Color bgColor, Color textColor, Color borderColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13))),
          Expanded(child: Text('Modbus RTU', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13))),
          Expanded(child: Text('Modbus TCP', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCompareRow(String feature, String rtu, String tcp, Color bgColor, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(feature, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(rtu, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12))),
          Expanded(child: Text(tcp, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12))),
        ],
      ),
    );
  }
}
