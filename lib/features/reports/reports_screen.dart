// Copyright (c) 2026 ntthang-dev. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        ConnectionState,
        FittedBox,
        FutureBuilder,
        GestureDetector,
        Scaffold,
        SingleChildScrollView,
        Theme,
        ThemeData,
        TimeOfDay,
        showDatePicker,
        showTimePicker;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';

import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/features/reports/pdf_report_helper.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/src/rust/api/historian.dart';

enum ReportRange {
  snapshot,
  last24h,
  last7d,
  custom,
}

enum ReportFormat {
  pdf,
  csv,
}

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

    // States
    final selectedRange = useState<ReportRange>(ReportRange.snapshot);
    final selectedFormat = useState<ReportFormat>(ReportFormat.pdf);
    final customStart = useState<DateTime>(DateTime.now().subtract(const Duration(hours: 24)));
    final customEnd = useState<DateTime>(DateTime.now());
    final isGenerating = useState<bool>(false);
    final exportMessage = useState<String?>(null);

    void showToast(String message) {
      exportMessage.value = message;
      Timer(const Duration(seconds: 4), () {
        exportMessage.value = null;
      });
    }

    DateTime getStartRange() {
      final now = DateTime.now();
      switch (selectedRange.value) {
        case ReportRange.last24h:
          return now.subtract(const Duration(hours: 24));
        case ReportRange.last7d:
          return now.subtract(const Duration(days: 7));
        case ReportRange.custom:
          return customStart.value;
        case ReportRange.snapshot:
          return now;
      }
    }

    DateTime getEndRange() {
      switch (selectedRange.value) {
        case ReportRange.custom:
          return customEnd.value;
        default:
          return DateTime.now();
      }
    }

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
                    color: subtextColor.withOpacity(0.3),
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
                    'Compliance & Diagnostic Reports',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure range, format, and generate handover reports for active nodes.',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ),

            // Main body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sidebar Configuration Panel (Left)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: isField ? CupertinoColors.systemGrey6 : const Color(0xFF121216),
                      border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'REPORT TYPE & RANGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subtextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRangeTile(
                            range: ReportRange.snapshot,
                            title: 'Current Snapshot',
                            subtitle: 'Active register values & rules',
                            icon: CupertinoIcons.camera_fill,
                            selectedRange: selectedRange,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            borderColor: borderColor,
                            isField: isField,
                          ),
                          _buildRangeTile(
                            range: ReportRange.last24h,
                            title: 'Last 24 Hours',
                            subtitle: 'Historical telemetry & alarms for past day',
                            icon: CupertinoIcons.clock_fill,
                            selectedRange: selectedRange,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            borderColor: borderColor,
                            isField: isField,
                          ),
                          _buildRangeTile(
                            range: ReportRange.last7d,
                            title: 'Last 7 Days',
                            subtitle: 'Historical telemetry & alarms for past week',
                            icon: CupertinoIcons.calendar_today,
                            selectedRange: selectedRange,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            borderColor: borderColor,
                            isField: isField,
                          ),
                          _buildRangeTile(
                            range: ReportRange.custom,
                            title: 'Custom Range',
                            subtitle: 'Manually specify custom datetime window',
                            icon: CupertinoIcons.calendar,
                            selectedRange: selectedRange,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            borderColor: borderColor,
                            isField: isField,
                          ),

                          // Custom Range Selectors (if Custom Range is selected)
                          if (selectedRange.value == ReportRange.custom) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isField ? CupertinoColors.white : const Color(0xFF1B1B22),
                                border: Border.all(color: borderColor, width: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'START DATETIME',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: subtextColor),
                                  ),
                                  const SizedBox(height: 4),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isField ? CupertinoColors.extraLightBackgroundGray : const Color(0xFF262630),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDateTime(customStart.value),
                                            style: TextStyle(fontSize: 12, color: textColor),
                                          ),
                                          Icon(CupertinoIcons.calendar, size: 16, color: subtextColor),
                                        ],
                                      ),
                                    ),
                                    onPressed: () => _selectDateTime(context, true, customStart, customEnd),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'END DATETIME',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: subtextColor),
                                  ),
                                  const SizedBox(height: 4),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isField ? CupertinoColors.extraLightBackgroundGray : const Color(0xFF262630),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDateTime(customEnd.value),
                                            style: TextStyle(fontSize: 12, color: textColor),
                                          ),
                                          Icon(CupertinoIcons.calendar, size: 16, color: subtextColor),
                                        ],
                                      ),
                                    ),
                                    onPressed: () => _selectDateTime(context, false, customStart, customEnd),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          Text(
                            'EXPORT FORMAT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subtextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildFormatCard(
                                format: ReportFormat.pdf,
                                label: 'PDF Report',
                                icon: CupertinoIcons.doc_text,
                                selectedFormat: selectedFormat,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                borderColor: borderColor,
                                isField: isField,
                              ),
                              const SizedBox(width: 8),
                              _buildFormatCard(
                                format: ReportFormat.csv,
                                label: 'CSV Export',
                                icon: CupertinoIcons.square_grid_2x2,
                                selectedFormat: selectedFormat,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                borderColor: borderColor,
                                isField: isField,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                          // Export Action Button (For CSV, or PDF historical logs)
                          if (selectedFormat.value == ReportFormat.csv || selectedRange.value != ReportRange.snapshot) ...[
                            CupertinoButton.filled(
                              onPressed: isGenerating.value
                                  ? null
                                  : () async {
                                      isGenerating.value = true;
                                      try {
                                        final start = getStartRange();
                                        final end = getEndRange();
                                        final connConfig = connState.activeConfig;
                                        final ip = connConfig?.ip ?? connConfig?.portName ?? 'MockNode';

                                        if (selectedFormat.value == ReportFormat.pdf) {
                                          final telemetry = await _getTelemetry(start, end);
                                          final alarms = await _getAlarms(start, end);

                                          final pdf = await PdfReportHelper.generateHistoricalReport(
                                            deviceName: connState.activeIp ?? 'Unknown Node',
                                            protocolType: connState.activeConfig?.protocolType ?? 'TCP',
                                            telemetryPoints: telemetry,
                                            alarmLogs: alarms,
                                            startRange: start,
                                            endRange: end,
                                          );

                                          final bytes = await pdf.save();
                                          await Printing.sharePdf(
                                            bytes: bytes,
                                            filename: 'modbus_studio_report_${ip}_${start.millisecondsSinceEpoch}.pdf',
                                          );
                                          showToast('PDF Export Dialog opened.');
                                        } else {
                                          final telemetry = await _getTelemetry(start, end);
                                          final alarms = await _getAlarms(start, end);

                                          final csv = _generateCsvString(telemetry, alarms);

                                          // Save copy to Documents
                                          final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
                                          final dir = Directory('$home/Documents/ModbusStudio/Reports');
                                          if (!await dir.exists()) {
                                            await dir.create(recursive: true);
                                          }
                                          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
                                          final localFile = File('${dir.path}/report_$timestamp.csv');
                                          await localFile.writeAsString(csv);

                                          // Prompt native share/save dialog
                                          await Printing.sharePdf(
                                            bytes: utf8.encode(csv),
                                            filename: 'modbus_studio_report_${ip}_${start.millisecondsSinceEpoch}.csv',
                                          );
                                          showToast('CSV saved locally & export dialog opened.');
                                        }
                                      } catch (e) {
                                        showToast('Export failed: $e');
                                      } finally {
                                        isGenerating.value = false;
                                      }
                                    },
                              child: isGenerating.value
                                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(CupertinoIcons.share, size: 18),
                                          SizedBox(width: 8),
                                          Text('Export Report...', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                            ),
                          ],

                          if (exportMessage.value != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isField ? const Color(0xFFE6F4EA) : const Color(0xFF0F2C2A),
                                border: Border.all(color: CupertinoColors.systemTeal, width: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                exportMessage.value!,
                                style: const TextStyle(color: CupertinoColors.systemTeal, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Preview & Presentation Pane (Right)
                  Expanded(
                    child: selectedFormat.value == ReportFormat.pdf
                        ? Container(
                            color: isField ? Colors.grey[200] : const Color(0xFF0D0D10),
                            child: Theme(
                              data: ThemeData.dark().copyWith(
                                primaryColor: Colors.teal,
                                scaffoldBackgroundColor: const Color(0xFF0F0F12),
                              ),
                              child: Scaffold(
                                body: PdfPreview(
                                  key: ValueKey('${selectedRange.value}_${customStart.value.millisecondsSinceEpoch}_${customEnd.value.millisecondsSinceEpoch}'),
                                  build: (format) async {
                                    if (selectedRange.value == ReportRange.snapshot) {
                                      final pdf = await PdfReportHelper.generateReport(
                                        deviceName: connState.activeIp ?? 'Unknown Node',
                                        protocolType: connState.activeConfig?.protocolType ?? 'TCP',
                                        connectionDetails: 'IP: ${connState.activeConfig?.ip ?? "N/A"}, Port: ${connState.activeConfig?.port ?? "N/A"}, Port Name: ${connState.activeConfig?.portName ?? "N/A"}',
                                        registers: connState.registers,
                                        rules: alarmState.rules,
                                        logs: alarmState.logs,
                                      );
                                      return pdf.save();
                                    } else {
                                      final start = getStartRange();
                                      final end = getEndRange();
                                      final telemetry = await _getTelemetry(start, end);
                                      final alarms = await _getAlarms(start, end);
                                      final pdf = await PdfReportHelper.generateHistoricalReport(
                                        deviceName: connState.activeIp ?? 'Unknown Node',
                                        protocolType: connState.activeConfig?.protocolType ?? 'TCP',
                                        telemetryPoints: telemetry,
                                        alarmLogs: alarms,
                                        startRange: start,
                                        endRange: end,
                                      );
                                      return pdf.save();
                                    }
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
                          )
                        : _buildCsvPreview(
                            key: ValueKey('${selectedRange.value}_${customStart.value.millisecondsSinceEpoch}_${customEnd.value.millisecondsSinceEpoch}'),
                            start: getStartRange(),
                            end: getEndRange(),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            borderColor: borderColor,
                            isField: isField,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeTile({
    required ReportRange range,
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueNotifier<ReportRange> selectedRange,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required bool isField,
  }) {
    final isSelected = selectedRange.value == range;
    final bg = isSelected
        ? (isField ? CupertinoColors.systemTeal.withOpacity(0.08) : const Color(0xFF0F2C2A))
        : (isField ? CupertinoColors.white : const Color(0xFF16161A));
    final borderCol = isSelected
        ? CupertinoColors.systemTeal
        : (isField ? const Color(0xFFD1D1D6) : const Color(0xFF2C2C35));

    return GestureDetector(
      onTap: () => selectedRange.value = range,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderCol, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? CupertinoColors.systemTeal : subtextColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required ReportFormat format,
    required String label,
    required IconData icon,
    required ValueNotifier<ReportFormat> selectedFormat,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required bool isField,
  }) {
    final isSelected = selectedFormat.value == format;
    final bg = isSelected
        ? (isField ? CupertinoColors.systemTeal.withOpacity(0.08) : const Color(0xFF0F2C2A))
        : (isField ? CupertinoColors.white : const Color(0xFF16161A));
    final borderCol = isSelected
        ? CupertinoColors.systemTeal
        : (isField ? const Color(0xFFD1D1D6) : const Color(0xFF2C2C35));

    return Expanded(
      child: GestureDetector(
        onTap: () => selectedFormat.value = format,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderCol, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? CupertinoColors.systemTeal : subtextColor,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCsvPreview({
    required Key key,
    required DateTime start,
    required DateTime end,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required bool isField,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      key: key,
      future: _fetchHistoricalCounts(start, end),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.systemTeal),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data: ${snapshot.error}',
              style: TextStyle(color: textColor),
            ),
          );
        }

        final data = snapshot.data!;
        final teleCount = data['telemetryCount'] as int;
        final alarmCount = data['alarmCount'] as int;
        final previewText = data['preview'] as String;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CSV Compliance Export Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              // Stats Cards
              Row(
                children: [
                  _buildStatCard(
                    title: 'Telemetry Rows',
                    value: teleCount.toString(),
                    icon: CupertinoIcons.graph_square,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                    isField: isField,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    title: 'Alarm Events',
                    value: alarmCount.toString(),
                    icon: CupertinoIcons.bell,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                    isField: isField,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Snippet title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview (First 15 lines)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtextColor),
                  ),
                  Text(
                    'Local copy: ~/Documents/ModbusStudio/Reports/',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Preview Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isField ? CupertinoColors.extraLightBackgroundGray : const Color(0xFF16161A),
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      previewText.isEmpty ? '(No records found in this range)' : previewText,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: isField ? CupertinoColors.black : const Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required bool isField,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isField ? CupertinoColors.white : const Color(0xFF1E1E24),
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: CupertinoColors.systemTeal, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<HistorianPoint>> _getTelemetry(DateTime start, DateTime end) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return [];
    }
    return getTelemetryLogsByRange(
      dbPath: "historian.db",
      startTs: start.millisecondsSinceEpoch,
      endTs: end.millisecondsSinceEpoch,
    );
  }

  Future<List<AlarmLog>> _getAlarms(DateTime start, DateTime end) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return [];
    }
    return dbGetAlarmLogsByRange(
      dbPath: "historian.db",
      startTs: start.millisecondsSinceEpoch,
      endTs: end.millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>> _fetchHistoricalCounts(DateTime start, DateTime end) async {
    final telemetry = await _getTelemetry(start, end);
    final alarms = await _getAlarms(start, end);
    final csv = _generateCsvString(telemetry, alarms);
    // Get first 15 lines of CSV
    final lines = csv.split('\n');
    final previewLines = lines.take(15).join('\n');
    return {
      'telemetryCount': telemetry.length,
      'alarmCount': alarms.length,
      'preview': previewLines,
      'fullCsv': csv,
    };
  }

  String _generateCsvString(List<HistorianPoint> telemetry, List<AlarmLog> alarms) {
    final buffer = StringBuffer();

    buffer.writeln("=== TELEMETRY LOGS ===");
    buffer.writeln("Timestamp,Register Address,Value");
    for (final p in telemetry) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.timestampMs.toInt());
      buffer.writeln("${dt.toIso8601String()},${p.address},${p.value}");
    }

    buffer.writeln();

    buffer.writeln("=== ALARM EVENTS ===");
    buffer.writeln("Timestamp,Severity,Address,Value,Message");
    for (final l in alarms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(l.timestamp.toInt());
      buffer.writeln("${dt.toIso8601String()},${l.severity},${l.registerAddress},${l.value},\"${l.message}\"");
    }

    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateTime(
    BuildContext context,
    bool isStart,
    ValueNotifier<DateTime> customStart,
    ValueNotifier<DateTime> customEnd,
  ) async {
    final DateTime initialDate = isStart ? customStart.value : customEnd.value;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    if (!context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (isStart) {
      customStart.value = newDateTime;
    } else {
      customEnd.value = newDateTime;
    }
  }
}
