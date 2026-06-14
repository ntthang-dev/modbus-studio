import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/features/navigation/responsive_navigation_shell.dart';
import 'package:modbus_studio/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Modbus Studio',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.systemTeal,
        scaffoldBackgroundColor: Color(0xFF0A0A0C), // Deep dark Apple style
      ),
      home: ResponsiveNavigationShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
