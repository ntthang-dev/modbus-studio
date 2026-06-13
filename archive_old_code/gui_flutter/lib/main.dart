import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:macos_ui/macos_ui.dart';
import 'pages/inspector_page.dart';
import 'pages/scanner_page.dart';
import 'pages/simulator_page.dart';
import 'pages/gateway_page.dart';
import 'pages/monitor_page.dart';
import 'pages/settings_page.dart';
import 'services/ws_service.dart';

void main() {
  runApp(const ModbusStudioApp());
}

class ModbusStudioApp extends StatelessWidget {
  const ModbusStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Modbus Studio',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int pageIndex = 0;
  final _ws = WSService();

  @override
  void initState() {
    super.initState();
    _ws.connect();
    _ws.addListener(_onWsChange);
  }

  @override
  void dispose() {
    _ws.removeListener(_onWsChange);
    super.dispose();
  }

  void _onWsChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 200,
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: pageIndex,
            onChanged: (index) {
              setState(() => pageIndex = index);
            },
            items: const [
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.search),
                label: Text('Inspector'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.antenna_radiowaves_left_right),
                label: Text('Scanner'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.desktopcomputer),
                label: Text('Simulator'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.arrow_right_arrow_left),
                label: Text('Gateway'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.chart_bar_alt_fill),
                label: Text('Monitor'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.settings),
                label: Text('Settings'),
              ),
            ],
          );
        },
        bottom: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.circle_filled,
                color: _ws.isConnected
                    ? CupertinoColors.systemGreen.resolveFrom(context)
                    : CupertinoColors.systemRed.resolveFrom(context),
                size: 10,
              ),
              const SizedBox(width: 8),
              Text(
                _ws.isConnected ? 'Core Connected' : 'Disconnected',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      child: IndexedStack(
        index: pageIndex,
        children: const [
          InspectorPage(),
          ScannerPage(),
          SimulatorPage(),
          GatewayPage(),
          MonitorPage(),
          SettingsPage(),
        ],
      ),
    );
  }
}
