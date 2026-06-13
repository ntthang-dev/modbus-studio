import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});

  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  final _ws = WSService();
  final _portCtrl = TextEditingController(text: '5020');
  final _injPortCtrl = TextEditingController(text: '5020');
  final _injAddrCtrl = TextEditingController(text: '0');
  final _injValCtrl = TextEditingController(text: '1234');
  List<String> _activeSlaves = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _ws.on('list_slaves', _onListSlaves);
    _ws.on('start_slave', _onSlaveAction);
    _ws.on('stop_slave', _onSlaveAction);
    _ws.on('set_virtual_register', _onSlaveAction);
    _ws.sendCommand({'cmd': 'list_slaves'});
  }

  @override
  void dispose() {
    _ws.off('list_slaves', _onListSlaves);
    _ws.off('start_slave', _onSlaveAction);
    _ws.off('stop_slave', _onSlaveAction);
    _ws.off('set_virtual_register', _onSlaveAction);
    _portCtrl.dispose();
    _injPortCtrl.dispose();
    _injAddrCtrl.dispose();
    _injValCtrl.dispose();
    super.dispose();
  }

  void _onListSlaves(Map<String, dynamic> data) {
    setState(() {
      final rawList = data['data'] as List<dynamic>? ?? [];
      _activeSlaves = rawList.map((e) => e.toString()).toList();
    });
  }

  void _onSlaveAction(Map<String, dynamic> data) {
    setState(() {
      if (data['status'] == 'error') {
        _error = data['error'] ?? '';
      } else {
        _error = '';
      }
    });
    // Refresh list after action
    Future.delayed(const Duration(milliseconds: 300), () {
      _ws.sendCommand({'cmd': 'list_slaves'});
    });
  }

  void _startSlave() {
    _ws.sendCommand({'cmd': 'start_slave', 'port': _portCtrl.text});
  }

  void _stopSlave(String port) {
    _ws.sendCommand({'cmd': 'stop_slave', 'port': port});
  }

  void _injectValue() {
    _ws.sendCommand({
      'cmd': 'set_virtual_register',
      'port': _injPortCtrl.text,
      'address': int.tryParse(_injAddrCtrl.text) ?? 0,
      'value': int.tryParse(_injValCtrl.text) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('Virtual Devices'),
        actions: [
          ToolBarIconButton(
            label: 'Refresh',
            icon: const MacosIcon(CupertinoIcons.refresh),
            showLabel: true,
            onPressed: () => _ws.sendCommand({'cmd': 'list_slaves'}),
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Virtual Slave', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 4),
                  Text('Spawn a virtual Modbus TCP slave for testing', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF999999) : const Color(0xFF666666))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 120, child: MacosTextField(controller: _portCtrl, placeholder: 'Port (e.g. 5020)')),
                      const SizedBox(width: 12),
                      PushButton(controlSize: ControlSize.large, onPressed: _startSlave, child: const Text('Start Slave')),
                    ],
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error, style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12)),
                    ),

                  const SizedBox(height: 30),
                  Text('Active Slaves (${_activeSlaves.length})', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 12),

                  if (_activeSlaves.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No virtual slaves running', style: TextStyle(color: isDark ? const Color(0xFF666666) : const Color(0xFF999999)))),
                    ),

                  ..._activeSlaves.map((port) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.circle_filled, size: 10, color: CupertinoColors.systemGreen.resolveFrom(context)),
                        const SizedBox(width: 8),
                        Text('TCP Slave on port $port', style: const TextStyle(fontFamily: 'Menlo', fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('(0.0.0.0:$port)', style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
                        const Spacer(),
                        PushButton(
                          controlSize: ControlSize.small,
                          secondary: true,
                          onPressed: () => _stopSlave(port),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 30),
                  Text('Memory Injector', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 4),
                  Text('Write directly into a virtual slave\'s memory', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF999999) : const Color(0xFF666666))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 80, child: MacosTextField(controller: _injPortCtrl, placeholder: 'Port')),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: MacosTextField(controller: _injAddrCtrl, placeholder: 'Addr')),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: MacosTextField(controller: _injValCtrl, placeholder: 'Value')),
                      const SizedBox(width: 16),
                      PushButton(
                        controlSize: ControlSize.large,
                        secondary: true,
                        onPressed: _injectValue,
                        child: const Text('Inject Value'),
                      ),
                    ],
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
