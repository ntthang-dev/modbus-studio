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

class RadarScreen extends StatelessWidget {
  const RadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Modbus Studio Radar'),
      ),
      child: Center(
        child: Text(
          'Rust API: ${initScanner()}',
        ),
      ),
    );
  }
}
