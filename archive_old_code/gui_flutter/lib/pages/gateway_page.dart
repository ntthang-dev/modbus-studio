import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/ws_service.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  final _ws = WSService();
  final _tcpPortCtrl = TextEditingController(text: '502');
  final _rtuPortCtrl = TextEditingController(text: '/dev/ttyUSB0');
  final _baudCtrl = TextEditingController(text: '9600');
  
  List<Map<String, dynamic>> _gateways = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _ws.on('list_gateways', _onListGateways);
    _ws.on('start_gateway', _onGatewayAction);
    _ws.on('stop_gateway', _onGatewayAction);
    _ws.sendCommand({'cmd': 'list_gateways'});
  }

  @override
  void dispose() {
    _ws.off('list_gateways', _onListGateways);
    _ws.off('start_gateway', _onGatewayAction);
    _ws.off('stop_gateway', _onGatewayAction);
    _tcpPortCtrl.dispose();
    _rtuPortCtrl.dispose();
    _baudCtrl.dispose();
    super.dispose();
  }

  void _onListGateways(Map<String, dynamic> data) {
    setState(() {
      final rawList = data['data'] as List<dynamic>? ?? [];
      _gateways = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  void _onGatewayAction(Map<String, dynamic> data) {
    setState(() {
      if (data['status'] == 'error') {
        _error = data['error'] ?? '';
      } else {
        _error = '';
      }
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _ws.sendCommand({'cmd': 'list_gateways'});
    });
  }

  void _startGateway() {
    _ws.sendCommand({
      'cmd': 'start_gateway',
      'port': _tcpPortCtrl.text,
      'target': _rtuPortCtrl.text,
      'baud': int.tryParse(_baudCtrl.text) ?? 9600,
    });
  }

  void _stopGateway(String port) {
    _ws.sendCommand({'cmd': 'stop_gateway', 'port': port});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);

    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('Modbus Gateway'),
        actions: [
          ToolBarIconButton(
            label: 'Refresh',
            icon: const MacosIcon(CupertinoIcons.refresh),
            showLabel: true,
            onPressed: () => _ws.sendCommand({'cmd': 'list_gateways'}),
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
                  Text('TCP to RTU Bridge', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 4),
                  Text('Expose a Modbus RTU serial network as a Modbus TCP server', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF999999) : const Color(0xFF666666))),
                  const SizedBox(height: 16),
                  
                  // Form
                  Row(
                    children: [
                      SizedBox(width: 100, child: MacosTextField(controller: _tcpPortCtrl, placeholder: 'TCP Port (502)')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(CupertinoIcons.arrow_right_arrow_left)),
                      Expanded(child: MacosTextField(controller: _rtuPortCtrl, placeholder: 'Serial Port (/dev/ttyUSB0)')),
                      const SizedBox(width: 10),
                      SizedBox(width: 100, child: MacosTextField(controller: _baudCtrl, placeholder: 'Baud Rate')),
                      const SizedBox(width: 16),
                      PushButton(
                        controlSize: ControlSize.large,
                        onPressed: _startGateway,
                        child: const Text('Start Bridge'),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error, style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12)),
                    ),

                  const SizedBox(height: 40),
                  
                  // Active Bridges
                  Text('Active Bridges (${_gateways.length})', style: MacosTheme.of(context).typography.title3),
                  const SizedBox(height: 12),
                  
                  if (_gateways.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No active bridges', style: TextStyle(color: isDark ? const Color(0xFF666666) : const Color(0xFF999999)))),
                    ),

                  ..._gateways.map((gw) {
                    final port = gw['tcp_port'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.circle_filled, size: 10, color: CupertinoColors.systemGreen.resolveFrom(context)),
                          const SizedBox(width: 8),
                          Text('TCP Port $port', style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Text('bridged to RTU Network', style: TextStyle(fontSize: 12)),
                          const Spacer(),
                          PushButton(
                            controlSize: ControlSize.small,
                            secondary: true,
                            onPressed: () => _stopGateway(port),
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
