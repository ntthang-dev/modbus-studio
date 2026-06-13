import 'package:flutter/cupertino.dart';
import 'package:modbus_studio/src/rust/api/scanner.dart';
import 'package:modbus_studio/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: RadarScreen(),
    );
  }
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final List<RadarDevice> _devices = [];
  bool _isScanning = false;

  void _startScan() {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    startMockRadarScan().listen(
      (device) {
        setState(() {
          _devices.add(device);
        });
      },
      onDone: () {
        setState(() {
          _isScanning = false;
        });
      },
      onError: (e) {
        setState(() {
          _isScanning = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Modbus Studio Radar'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isScanning ? null : _startScan,
          child: _isScanning 
              ? const CupertinoActivityIndicator() 
              : const Text('Scan'),
        ),
      ),
      child: SafeArea(
        child: _devices.isEmpty && !_isScanning
            ? const Center(child: Text('Tap Scan to start'))
            : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.systemGrey4,
                          width: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.ip, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('${device.status} - ${device.latencyMs}ms', style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
