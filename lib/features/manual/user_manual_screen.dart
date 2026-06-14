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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modbus Protocol Basics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Text(
          'Modbus is a standard request/reply industrial protocol utilizing master/slave architectures. Data is categorized into four primary memory blocks:',
          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        ),
        const SizedBox(height: 16),
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
}
