import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class InspectorPage extends StatefulWidget {
  const InspectorPage({super.key});

  @override
  State<InspectorPage> createState() => _InspectorPageState();
}

class _InspectorPageState extends State<InspectorPage> {
  final _ws = WSService();
  final _targetCtrl = TextEditingController(text: '127.0.0.1:5020');
  final _slaveCtrl = TextEditingController(text: '1');
  final _addrCtrl = TextEditingController(text: '0');
  final _countCtrl = TextEditingController(text: '10');
  final _valCtrl = TextEditingController(text: '0');

  String _funcType = 'holding';
  bool _isRTU = false;
  bool _isLoading = false;
  List<int> _readData = [];
  int _latency = 0;
  String _error = '';
  String _statusText = 'Ready';

  @override
  void initState() {
    super.initState();
    _ws.on('read', _onRead);
    _ws.on('write', _onWrite);
  }

  @override
  void dispose() {
    _ws.off('read', _onRead);
    _ws.off('write', _onWrite);
    _targetCtrl.dispose();
    _slaveCtrl.dispose();
    _addrCtrl.dispose();
    _countCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  void _onRead(Map<String, dynamic> data) {
    setState(() {
      _isLoading = false;
      if (data['status'] == 'error') {
        _error = data['error'] ?? 'Unknown error';
        _statusText = 'Error';
        _readData = [];
      } else {
        _error = '';
        _latency = data['latency_ms'] ?? 0;
        _readData = (data['data'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
        _statusText = 'Read OK — ${_readData.length} registers in ${_latency}ms';
      }
    });
  }

  void _onWrite(Map<String, dynamic> data) {
    setState(() {
      _isLoading = false;
      if (data['status'] == 'error') {
        _error = data['error'] ?? 'Unknown error';
        _statusText = 'Write Error';
      } else {
        _error = '';
        _latency = data['latency_ms'] ?? 0;
        _statusText = 'Write OK in ${_latency}ms';
      }
    });
  }

  void _sendRead() {
    setState(() { _isLoading = true; _error = ''; _statusText = 'Reading...'; });
    _ws.sendCommand({
      'cmd': 'read',
      'target': _targetCtrl.text,
      'is_rtu': _isRTU,
      'slave_id': int.tryParse(_slaveCtrl.text) ?? 1,
      'type': _funcType,
      'address': int.tryParse(_addrCtrl.text) ?? 0,
      'count': int.tryParse(_countCtrl.text) ?? 10,
    });
  }

  void _sendWrite() {
    setState(() { _isLoading = true; _error = ''; _statusText = 'Writing...'; });
    _ws.sendCommand({
      'cmd': 'write',
      'target': _targetCtrl.text,
      'is_rtu': _isRTU,
      'slave_id': int.tryParse(_slaveCtrl.text) ?? 1,
      'type': _funcType,
      'address': int.tryParse(_addrCtrl.text) ?? 0,
      'value': int.tryParse(_valCtrl.text) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('Modbus Inspector'),
        actions: [
          ToolBarIconButton(
            label: 'Read',
            icon: const MacosIcon(CupertinoIcons.play_fill),
            showLabel: true,
            onPressed: _isLoading ? null : _sendRead,
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Column(
              children: [
                // Status Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _error.isNotEmpty ? CupertinoIcons.xmark_circle_fill
                            : _isLoading ? CupertinoIcons.clock_fill
                            : CupertinoIcons.checkmark_circle_fill,
                        size: 12,
                        color: _error.isNotEmpty ? CupertinoColors.systemRed
                            : _isLoading ? CupertinoColors.systemOrange
                            : CupertinoColors.systemGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_statusText, style: const TextStyle(fontSize: 11))),
                      if (_latency > 0) Text('Latency: ${_latency}ms', style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGreen)),
                    ],
                  ),
                ),
                // Controls
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection Section
                        Text('Connection', style: MacosTheme.of(context).typography.title3),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            MacosCheckbox(value: _isRTU, onChanged: (v) => setState(() => _isRTU = v)),
                            const SizedBox(width: 8),
                            const Text('RTU'),
                            const SizedBox(width: 20),
                            Expanded(child: MacosTextField(controller: _targetCtrl, placeholder: _isRTU ? '/dev/ttyUSB0' : 'IP:Port')),
                            const SizedBox(width: 10),
                            SizedBox(width: 80, child: MacosTextField(controller: _slaveCtrl, placeholder: 'Slave ID')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Function Section
                        Text('Function', style: MacosTheme.of(context).typography.title3),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            MacosPopupButton<String>(
                              value: _funcType,
                              onChanged: (v) => setState(() => _funcType = v!),
                              items: const [
                                MacosPopupMenuItem(value: 'holding', child: Text('Holding Registers (FC03)')),
                                MacosPopupMenuItem(value: 'input', child: Text('Input Registers (FC04)')),
                                MacosPopupMenuItem(value: 'coil', child: Text('Coils (FC01)')),
                                MacosPopupMenuItem(value: 'discrete', child: Text('Discrete Inputs (FC02)')),
                              ],
                            ),
                            const SizedBox(width: 10),
                            SizedBox(width: 100, child: MacosTextField(controller: _addrCtrl, placeholder: 'Address')),
                            const SizedBox(width: 10),
                            SizedBox(width: 80, child: MacosTextField(controller: _countCtrl, placeholder: 'Count')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Actions
                        Row(
                          children: [
                            PushButton(
                              controlSize: ControlSize.large,
                              onPressed: _isLoading ? null : _sendRead,
                              child: const Text('Read'),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(width: 120, child: MacosTextField(controller: _valCtrl, placeholder: 'Value')),
                            const SizedBox(width: 8),
                            PushButton(
                              controlSize: ControlSize.large,
                              secondary: true,
                              onPressed: _isLoading ? null : _sendWrite,
                              child: const Text('Write'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error, style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12)),
                          ),

                        const SizedBox(height: 24),

                        // Data Table
                        if (_readData.isNotEmpty) ...[
                          Text('Register Data', style: MacosTheme.of(context).typography.title3),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: headerBg,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                  child: const Row(children: [
                                    SizedBox(width: 60, child: Text('Addr', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 70, child: Text('UInt16', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 70, child: Text('Int16', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 80, child: Text('Float32', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 70, child: Text('Hex', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 100, child: Text('Binary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    Expanded(child: Text('ASCII', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                  ]),
                                ),
                                // Data rows
                                ...List.generate(_readData.length, (i) {
                                  final v = _readData[i];
                                  final int16 = v > 32767 ? v - 65536 : v;
                                  String floatStr = '-';
                                  if (i < _readData.length - 1) {
                                    final bd = ByteData(4);
                                    bd.setUint16(0, v);
                                    bd.setUint16(2, _readData[i+1]);
                                    floatStr = bd.getFloat32(0).toStringAsFixed(4);
                                  }
                                  final hex = '0x${v.toRadixString(16).padLeft(4, '0').toUpperCase()}';
                                  final bin = v.toRadixString(2).padLeft(16, '0');
                                  final hi = (v >> 8) & 0xFF;
                                  final lo = v & 0xFF;
                                  final ascii = String.fromCharCodes([
                                    if (hi >= 32 && hi <= 126) hi else 46,
                                    if (lo >= 32 && lo <= 126) lo else 46,
                                  ]);
                                  final addr = (int.tryParse(_addrCtrl.text) ?? 0) + i;
                                  final rowColor = i.isEven
                                      ? (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5))
                                      : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF));
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    color: rowColor,
                                    child: Row(children: [
                                      SizedBox(width: 60, child: Text('$addr', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 70, child: Text('$v', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 70, child: Text('$int16', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 80, child: Text(floatStr, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo', color: CupertinoColors.systemBlue))),
                                      SizedBox(width: 70, child: Text(hex, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 100, child: Text(bin, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      Expanded(child: Text(ascii, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                    ]),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
