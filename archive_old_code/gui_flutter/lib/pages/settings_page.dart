import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ws = WSService();
  final _coreUrlCtrl = TextEditingController(text: 'ws://127.0.0.1:8080/ws');
  List<String> _serialPorts = [];

  @override
  void initState() {
    super.initState();
    _ws.addListener(_onWsChange);
    _ws.on('list_serial_ports', _onListSerialPorts);
    _ws.sendCommand({'cmd': 'list_serial_ports'});
  }

  @override
  void dispose() {
    _ws.removeListener(_onWsChange);
    _ws.off('list_serial_ports', _onListSerialPorts);
    _coreUrlCtrl.dispose();
    super.dispose();
  }

  void _onListSerialPorts(Map<String, dynamic> data) {
    setState(() {
      final rawList = data['data'] as List<dynamic>? ?? [];
      _serialPorts = rawList.map((e) => e.toString()).toList();
    });
  }

  void _onWsChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: const ToolBar(title: Text('Settings')),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Core Connection
                  Text('Core Engine', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            CupertinoIcons.circle_filled,
                            size: 10,
                            color: _ws.isConnected
                                ? CupertinoColors.systemGreen.resolveFrom(context)
                                : CupertinoColors.systemRed.resolveFrom(context),
                          ),
                          const SizedBox(width: 8),
                          Text(_ws.isConnected ? 'Connected to Go Core' : 'Disconnected', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: MacosTextField(controller: _coreUrlCtrl, placeholder: 'WebSocket URL')),
                          const SizedBox(width: 12),
                          PushButton(
                            controlSize: ControlSize.regular,
                            onPressed: () => _ws.connect(),
                            child: const Text('Reconnect'),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Serial Ports
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Available Serial Ports', style: MacosTheme.of(context).typography.title3),
                      PushButton(
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () => _ws.sendCommand({'cmd': 'list_serial_ports'}),
                        child: const Text('Scan Ports'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_serialPorts.isEmpty)
                          const Text('No serial ports found or scanning...', style: TextStyle(color: CupertinoColors.systemGrey)),
                        ..._serialPorts.map((port) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.link, size: 14, color: CupertinoColors.systemBlue.resolveFrom(context)),
                              const SizedBox(width: 8),
                              Text(port, style: const TextStyle(fontFamily: 'Menlo', fontSize: 13)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // About
                  Text('About', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modbus Studio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                        SizedBox(height: 12),
                        Text(
                          'All-in-one Modbus SCADA tool for industrial engineers.\n'
                          'Supports TCP/RTU, Master/Slave/Gateway modes.\n\n'
                          'Architecture: Flutter (UI) + Go (Engine) + Rust (CLI)',
                          style: TextStyle(fontSize: 12),
                        ),
                        SizedBox(height: 12),
                        Text('Components:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('• Go Core Engine — Modbus TCP/RTU, WebSocket API', style: TextStyle(fontSize: 12, fontFamily: 'Menlo')),
                        Text('• Flutter Desktop — macOS native UI', style: TextStyle(fontSize: 12, fontFamily: 'Menlo')),
                        Text('• Rust CLI — Lightweight command-line tool', style: TextStyle(fontSize: 12, fontFamily: 'Menlo')),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
