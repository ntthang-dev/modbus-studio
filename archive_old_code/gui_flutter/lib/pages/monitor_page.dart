import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final _ws = WSService();
  final _targetCtrl = TextEditingController(text: '127.0.0.1:5020');
  final _slaveCtrl = TextEditingController(text: '1');
  final _addrCtrl = TextEditingController(text: '0');
  final _countCtrl = TextEditingController(text: '10');

  bool _isPolling = false;
  Timer? _pollTimer;
  int _intervalMs = 1000;
  List<int> _data = [];
  int _latency = 0;
  int _pollCount = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _ws.on('read', _onRead);
  }

  @override
  void dispose() {
    _ws.off('read', _onRead);
    _pollTimer?.cancel();
    _targetCtrl.dispose();
    _slaveCtrl.dispose();
    _addrCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _onRead(Map<String, dynamic> data) {
    if (!_isPolling) return;
    setState(() {
      if (data['status'] == 'error') {
        _error = data['error'] ?? '';
      } else {
        _error = '';
        _latency = data['latency_ms'] ?? 0;
        _data = (data['data'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
        _pollCount++;
      }
    });
  }

  void _startPolling() {
    setState(() { _isPolling = true; _pollCount = 0; });
    _doPoll();
    _pollTimer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) => _doPoll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    setState(() => _isPolling = false);
  }

  void _doPoll() {
    _ws.sendCommand({
      'cmd': 'read',
      'target': _targetCtrl.text,
      'slave_id': int.tryParse(_slaveCtrl.text) ?? 1,
      'type': 'holding',
      'address': int.tryParse(_addrCtrl.text) ?? 0,
      'count': int.tryParse(_countCtrl.text) ?? 10,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('Realtime Monitor'),
        actions: [
          ToolBarIconButton(
            label: _isPolling ? 'Stop' : 'Start',
            icon: MacosIcon(_isPolling ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill),
            showLabel: true,
            onPressed: _isPolling ? _stopPolling : _startPolling,
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Column(
              children: [
                // Status bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(children: [
                    Icon(
                      _isPolling ? CupertinoIcons.antenna_radiowaves_left_right : CupertinoIcons.stop_circle,
                      size: 12,
                      color: _isPolling ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPolling ? 'Polling (${_intervalMs}ms) — #$_pollCount — Latency: ${_latency}ms' : 'Stopped',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text('Error: $_error', style: const TextStyle(fontSize: 11, color: CupertinoColors.systemRed)),
                    ],
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monitor Configuration', style: MacosTheme.of(context).typography.title3),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: MacosTextField(controller: _targetCtrl, placeholder: 'Target')),
                          const SizedBox(width: 10),
                          SizedBox(width: 80, child: MacosTextField(controller: _slaveCtrl, placeholder: 'Slave')),
                          const SizedBox(width: 10),
                          SizedBox(width: 80, child: MacosTextField(controller: _addrCtrl, placeholder: 'Addr')),
                          const SizedBox(width: 10),
                          SizedBox(width: 60, child: MacosTextField(controller: _countCtrl, placeholder: 'Cnt')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Text('Interval:', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          MacosPopupButton<int>(
                            value: _intervalMs,
                            onChanged: (v) => setState(() => _intervalMs = v!),
                            items: const [
                              MacosPopupMenuItem(value: 100, child: Text('100ms')),
                              MacosPopupMenuItem(value: 250, child: Text('250ms')),
                              MacosPopupMenuItem(value: 500, child: Text('500ms')),
                              MacosPopupMenuItem(value: 1000, child: Text('1s')),
                              MacosPopupMenuItem(value: 2000, child: Text('2s')),
                              MacosPopupMenuItem(value: 5000, child: Text('5s')),
                            ],
                          ),
                          const SizedBox(width: 16),
                          PushButton(
                            controlSize: ControlSize.large,
                            onPressed: _isPolling ? _stopPolling : _startPolling,
                            child: Text(_isPolling ? 'Stop Polling' : 'Start Polling'),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        if (_data.isNotEmpty) ...[
                          Text('Live Data', style: MacosTheme.of(context).typography.title3),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(6)),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: headerBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                                  child: const Row(children: [
                                    SizedBox(width: 60, child: Text('Addr', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 80, child: Text('Value', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    SizedBox(width: 80, child: Text('Hex', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    Expanded(child: Text('Bar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                  ]),
                                ),
                                ...List.generate(_data.length, (i) {
                                  final v = _data[i];
                                  final addr = (int.tryParse(_addrCtrl.text) ?? 0) + i;
                                  final fraction = v / 65535.0;
                                  final rowColor = i.isEven
                                      ? (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5))
                                      : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF));
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    color: rowColor,
                                    child: Row(children: [
                                      SizedBox(width: 60, child: Text('$addr', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 80, child: Text('$v', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      SizedBox(width: 80, child: Text('0x${v.toRadixString(16).padLeft(4, '0').toUpperCase()}', style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
                                      Expanded(
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: fraction,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(4),
                                                color: CupertinoColors.systemBlue.resolveFrom(context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
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
