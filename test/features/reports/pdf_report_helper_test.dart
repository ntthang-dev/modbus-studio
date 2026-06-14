import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:modbus_studio/features/reports/pdf_report_helper.dart';

void main() {
  group('PdfReportHelper Unit Tests', () {
    test('generateReport handles empty registers, rules, and logs without crashing', () async {
      final doc = await PdfReportHelper.generateReport(
        deviceName: 'Test Node',
        protocolType: 'TCP',
        connectionDetails: 'IP: 192.168.1.100, Port: 502',
        registers: [],
        rules: [],
        logs: [],
      );

      expect(doc, isNotNull);
      expect(doc.document.pdfPageList.pages, isNotEmpty);
    });

    test('generateHistoricalReport handles empty telemetryPoints and alarmLogs without crashing', () async {
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final end = DateTime.now();

      final doc = await PdfReportHelper.generateHistoricalReport(
        deviceName: 'Test Node',
        protocolType: 'TCP',
        telemetryPoints: [],
        alarmLogs: [],
        startRange: start,
        endRange: end,
      );

      expect(doc, isNotNull);
      expect(doc.document.pdfPageList.pages, isNotEmpty);
    });
  });
}
