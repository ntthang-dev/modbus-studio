import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, Theme, ThemeData, Colors;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/features/reports/pdf_report_helper.dart';

class ReportsScreen extends HookConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final connState = ref.watch(connectionProvider);
    final alarmState = ref.watch(alarmProvider);

    final bool isField = uiState.isFieldMode;
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0A0A0C);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;
    final Color subtextColor = isField ? CupertinoColors.secondaryLabel : CupertinoColors.systemGrey2;
    final Color borderColor = isField ? const Color(0xFFD1D1D6) : const Color(0xFF2C2C35);

    if (!connState.isConnected) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.doc_text_fill,
                    size: 64,
                    color: subtextColor.withValues(alpha:0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reports Center Offline',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to a active Modbus TCP/Serial node to generate compliance diagnostic reports.',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: () {
                      ref.read(uiProvider.notifier).setScreen(AppScreen.hub);
                    },
                    child: const Text('Go to Connection Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostic PDF Reports',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Generate, print, or export handover and compliance reports for active nodes.',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ),

            // PDF Preview Viewer
            Expanded(
              child: Theme(
                // Wrap in MaterialApp theme to allow PdfPreview standard material buttons/layout to look clean
                data: ThemeData.dark().copyWith(
                  primaryColor: Colors.teal,
                  scaffoldBackgroundColor: const Color(0xFF0F0F12),
                ),
                child: Scaffold(
                  backgroundColor: isField ? Colors.grey[200] : const Color(0xFF0D0D10),
                  body: PdfPreview(
                    build: (format) async {
                      final pdf = await PdfReportHelper.generateReport(
                        deviceName: connState.activeIp ?? 'Unknown Node',
                        protocolType: connState.activeConfig?.protocolType ?? 'TCP',
                        connectionDetails: 'IP: ${connState.activeConfig?.ip ?? "N/A"}, Port: ${connState.activeConfig?.port ?? "N/A"}, Port Name: ${connState.activeConfig?.portName ?? "N/A"}',
                        registers: connState.registers,
                        rules: alarmState.rules,
                        logs: alarmState.logs,
                      );
                      return pdf.save();
                    },
                    pdfFileName: 'modbus_studio_report_${connState.activeIp}.pdf',
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    loadingWidget: const Center(
                      child: CupertinoActivityIndicator(color: CupertinoColors.systemTeal),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
