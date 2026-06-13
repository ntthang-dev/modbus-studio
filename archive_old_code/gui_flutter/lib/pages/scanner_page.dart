import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _ws = WSService();
  final _targetCtrl = TextEditingController(text: '127.0.0.1:5020');
  final _fromIDCtrl = TextEditingController(text: '1');
  final _toIDCtrl = TextEditingController(text: '20');
  final _slaveCtrl = TextEditingController(text: '1');
  final _fromAddrCtrl = TextEditingController(text: '0');
  final _toAddrCtrl = TextEditingController(text: '100');

  bool _isRTU = false;
  bool _scanningDevices = false;
  bool _scanningRegs = false;
  List<Map<String, dynamic>> _deviceResults = [];
  List<Map<String, dynamic>> _regResults = [];

  @override
  void initState() {
    super.initState();
    _ws.on('scan_devices', _onDeviceScan);
    _ws.on('scan_registers', _onRegScan);
  }

  @override
  void dispose() {
    _ws.off('scan_devices', _onDeviceScan);
    _ws.off('scan_registers', _onRegScan);
    _targetCtrl.dispose();
    _fromIDCtrl.dispose();
    _toIDCtrl.dispose();
    _slaveCtrl.dispose();
    _fromAddrCtrl.dispose();
    _toAddrCtrl.dispose();
    super.dispose();
  }

  void _onDeviceScan(Map<String, dynamic> data) {
    setState(() {
      _scanningDevices = false;
      final rawList = data['data'] as List<dynamic>? ?? [];
      _deviceResults = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  void _onRegScan(Map<String, dynamic> data) {
    setState(() {
      _scanningRegs = false;
      final rawList = data['data'] as List<dynamic>? ?? [];
      _regResults = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  void _scanDevices() {
    setState(() { _scanningDevices = true; _deviceResults = []; });
    _ws.sendCommand({
      'cmd': 'scan_devices',
      'target': _targetCtrl.text,
      'is_rtu': _isRTU,
      'from_id': int.tryParse(_fromIDCtrl.text) ?? 1,
      'to_id': int.tryParse(_toIDCtrl.text) ?? 247,
    });
  }

  void _scanRegisters() {
    setState(() { _scanningRegs = true; _regResults = []; });
    _ws.sendCommand({
      'cmd': 'scan_registers',
      'target': _targetCtrl.text,
      'is_rtu': _isRTU,
      'slave_id': int.tryParse(_slaveCtrl.text) ?? 1,
      'from_addr': int.tryParse(_fromAddrCtrl.text) ?? 0,
      'to_addr': int.tryParse(_toAddrCtrl.text) ?? 100,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: const ToolBar(title: Text('Modbus Scanner')),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection
                  Row(
                    children: [
                      MacosCheckbox(value: _isRTU, onChanged: (v) => setState(() => _isRTU = v)),
                      const SizedBox(width: 8),
                      const Text('RTU'),
                      const SizedBox(width: 20),
                      Expanded(child: MacosTextField(controller: _targetCtrl, placeholder: 'Target IP:Port or Serial Port')),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Device Scanner Section
                  Text('Device Scanner', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 4),
                  Text('Scan Slave IDs to find active devices on the bus', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF999999) : const Color(0xFF666666))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 80, child: MacosTextField(controller: _fromIDCtrl, placeholder: 'From')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                      SizedBox(width: 80, child: MacosTextField(controller: _toIDCtrl, placeholder: 'To')),
                      const SizedBox(width: 16),
                      PushButton(
                        controlSize: ControlSize.large,
                        onPressed: _scanningDevices ? null : _scanDevices,
                        child: Text(_scanningDevices ? 'Scanning...' : 'Scan Devices'),
                      ),
                      const SizedBox(width: 8),
                      if (!_scanningDevices && _deviceResults.isNotEmpty)
                        PushButton(
                          controlSize: ControlSize.large,
                          secondary: true,
                          onPressed: () {
                            final file = File('${Platform.environment['HOME']}/Desktop/device_scan.csv');
                            final csv = 'Slave ID,Latency,Status\n' + _deviceResults.map((e) => '${e['slave_id']},${e['latency_ms']},${e['status']}').join('\n');
                            file.writeAsStringSync(csv);
                            showMacosAlertDialog(
                              context: context,
                              builder: (_) => MacosAlertDialog(
                                appIcon: const Icon(CupertinoIcons.checkmark_circle_fill),
                                title: const Text('Export Successful'),
                                message: Text('Saved to ${file.path}'),
                                primaryButton: PushButton(controlSize: ControlSize.large, onPressed: () => Navigator.pop(context), child: const Text('OK')),
                              ),
                            );
                          },
                          child: const Text('Export CSV'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_scanningDevices)
                    const Row(children: [
                      CupertinoActivityIndicator(radius: 8),
                      SizedBox(width: 8),
                      Text('Scanning devices...', style: TextStyle(fontSize: 12)),
                    ]),
                  if (!_scanningDevices && _deviceResults.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: headerBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                            child: Row(children: [
                              const SizedBox(width: 60, child: Text('Slave ID', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              const SizedBox(width: 80, child: Text('Latency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              const Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            ]),
                          ),
                          ..._deviceResults.asMap().entries.map((e) {
                            final i = e.key;
                            final d = e.value;
                            final rowColor = i.isEven
                                ? (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5))
                                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF));
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: rowColor,
                              child: Row(children: [
                                SizedBox(width: 60, child: Text('${d['slave_id']}', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                SizedBox(width: 80, child: Text('${d['latency_ms']}ms', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                Expanded(child: Row(children: [
                                  Icon(CupertinoIcons.checkmark_circle_fill, size: 12, color: CupertinoColors.systemGreen.resolveFrom(context)),
                                  const SizedBox(width: 4),
                                  Text('${d['status']}', style: const TextStyle(fontSize: 12)),
                                ])),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                  if (!_scanningDevices && _deviceResults.isEmpty)
                    Text('Found ${_deviceResults.length} devices', style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),

                  const SizedBox(height: 40),

                  // Register Scanner Section
                  Text('Register Scanner', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 4),
                  Text('Scan holding registers to find non-zero values', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF999999) : const Color(0xFF666666))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 80, child: MacosTextField(controller: _slaveCtrl, placeholder: 'Slave ID')),
                      const SizedBox(width: 10),
                      SizedBox(width: 80, child: MacosTextField(controller: _fromAddrCtrl, placeholder: 'From')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                      SizedBox(width: 80, child: MacosTextField(controller: _toAddrCtrl, placeholder: 'To')),
                      const SizedBox(width: 16),
                      PushButton(
                        controlSize: ControlSize.large,
                        onPressed: _scanningRegs ? null : _scanRegisters,
                        child: Text(_scanningRegs ? 'Scanning...' : 'Scan Registers'),
                      ),
                      const SizedBox(width: 8),
                      if (!_scanningRegs && _regResults.isNotEmpty)
                        PushButton(
                          controlSize: ControlSize.large,
                          secondary: true,
                          onPressed: () {
                            final file = File('${Platform.environment['HOME']}/Desktop/register_scan.csv');
                            final csv = 'Address,Value,Hex\n' + _regResults.map((e) => '${e['address']},${e['value']},0x${(e['value'] as int).toRadixString(16).padLeft(4, '0')}').join('\n');
                            file.writeAsStringSync(csv);
                            showMacosAlertDialog(
                              context: context,
                              builder: (_) => MacosAlertDialog(
                                appIcon: const Icon(CupertinoIcons.checkmark_circle_fill),
                                title: const Text('Export Successful'),
                                message: Text('Saved to ${file.path}'),
                                primaryButton: PushButton(controlSize: ControlSize.large, onPressed: () => Navigator.pop(context), child: const Text('OK')),
                              ),
                            );
                          },
                          child: const Text('Export CSV'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_scanningRegs)
                    const Row(children: [
                      CupertinoActivityIndicator(radius: 8),
                      SizedBox(width: 8),
                      Text('Scanning registers...', style: TextStyle(fontSize: 12)),
                    ]),
                  if (!_scanningRegs && _regResults.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: headerBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                            child: const Row(children: [
                              SizedBox(width: 80, child: Text('Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              SizedBox(width: 80, child: Text('Value', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              SizedBox(width: 80, child: Text('Hex', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            ]),
                          ),
                          ..._regResults.asMap().entries.map((e) {
                            final i = e.key;
                            final d = e.value;
                            final v = d['value'] as int? ?? 0;
                            final rowColor = i.isEven
                                ? (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5))
                                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF));
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: rowColor,
                              child: Row(children: [
                                SizedBox(width: 80, child: Text('${d['address']}', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                SizedBox(width: 80, child: Text('$v', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                SizedBox(width: 80, child: Text('0x${v.toRadixString(16).padLeft(4, '0').toUpperCase()}', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                              ]),
                            );
                          }),
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
