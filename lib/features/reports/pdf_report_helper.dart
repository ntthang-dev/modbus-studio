import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:modbus_studio/src/rust/api/db.dart';

class PdfReportHelper {
  static Future<pw.Document> generateReport({
    required String deviceName,
    required String protocolType,
    required String connectionDetails,
    required List<int> registers,
    required List<AlarmRule> rules,
    required List<AlarmLog> logs,
  }) async {
    final pdf = pw.Document();

    final headers = ['Address', 'Dec Value', 'Hex Value', 'Status'];
    final registerRows = <List<String>>[];
    for (var i = 0; i < registers.length && i < 50; i++) {
      final addr = 40001 + i;
      final val = registers[i];
      final hex = '0x${val.toRadixString(16).toUpperCase().padLeft(4, '0')}';
      
      // Determine if active alarm is breached for this register
      String status = 'Nominal';
      for (final rule in rules) {
        if (rule.isEnabled && rule.registerAddress == addr) {
          bool isBreached = false;
          switch (rule.condition) {
            case '>': isBreached = val > rule.threshold; break;
            case '<': isBreached = val < rule.threshold; break;
            case '==': isBreached = val == rule.threshold; break;
            case '!=': isBreached = val != rule.threshold; break;
          }
          if (isBreached) {
            status = 'Breached (${rule.severity})';
            break;
          }
        }
      }

      registerRows.add([
        addr.toString(),
        val.toString(),
        hex,
        status,
      ]);
    }

    final ruleRows = rules.map((r) => [
      r.name,
      r.registerAddress.toString(),
      '${r.condition} ${r.threshold}',
      r.severity,
      r.isEnabled ? 'Active' : 'Disabled',
    ]).toList();

    final logRows = logs.take(30).map((l) {
      final dt = DateTime.fromMillisecondsSinceEpoch(l.timestamp.toInt());
      final timeStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      return [
        timeStr,
        l.severity,
        l.registerAddress.toString(),
        l.value.toString(),
        l.message,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Report Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MODBUS STUDIO DIAGNOSTIC REPORT',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Compliance & Operational Safety Handover',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateTime.now().toString().substring(0, 19),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Device Details Overview
            pw.Text('1. Connection Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Node Address: $deviceName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      pw.Expanded(child: pw.Text('Protocol Mode: $protocolType', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Details: $connectionDetails', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Section 2: Holding Registers Snapshot
            pw.Text('2. Holding Registers Snapshot (Top 50)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            if (registerRows.isEmpty)
              pw.Text('No register data available.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: registerRows,
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 9),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 24),

            // Section 3: Alarm Rules Configured
            pw.Text('3. Active Alarm Rules', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            if (ruleRows.isEmpty)
              pw.Text('No alarm rules configured.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Rule Name', 'Register Address', 'Condition', 'Severity', 'Status'],
                data: ruleRows,
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 24),

            // Section 4: Recent Alarm Event Logs
            pw.Text('4. Alarm Event Logs (Recent 30)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            if (logRows.isEmpty)
              pw.Text('No alarm events logged.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Timestamp', 'Severity', 'Address', 'Value', 'Message'],
                data: logRows,
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
          ];
        },
      ),
    );

    return pdf;
  }
}
