# Spec: Reports Module (PDF/CSV Exports)

## Objective
Enable SCADA operators to generate, view, and export formatted reports summarizing historic register telemetry and alarm history. Additionally, allow automated script-triggered exports via the Javascript scripting sandbox.

### User Stories & Use Cases
1. **Manual Shift Audit**: An operator on the Reports Screen selects a date range (e.g. "Last 24 Hours"), selects "All Data", and clicks "Generate PDF". They save the file to their desktop via a native save dialog.
2. **Automated Incident Logging**: A Javascript automation task runs every night at midnight. It evaluates the current alarm logs, generates a daily CSV report, and saves it silently to `~/Documents/ModbusStudio/Reports/`.

---

## Tech Stack
* **Flutter SDK**: v3.12+ (Cupertino styling)
* **Rust Toolchain**: Stable (SQLite backend integration)
* **Dart PDF Package**: `pdf: ^3.12.0` (Native Dart layout generation)
* **Dart Printing Package**: `printing: ^5.14.3` (Native macOS print/save dialog bridge)
* **QuickJS Sandbox**: `flutter_js: ^0.8.7` (Exposing reports API to custom scripts)

---

## Commands
* Generate bindings: `flutter_rust_bridge_codegen generate`
* Run tests: `flutter test`
* Build macOS: `flutter build macos --no-codesign`

---

## Project Structure
* `lib/features/reports/` -> Reports UI components and logic helpers
* `lib/features/scripting/` -> QuickJS JavaScript bindings extension
* `rust/src/api/historian.rs` -> SQLite telemetry logs query expansion

---

## Code Style
Reports and PDFs will use structured typography with standard layout guidelines:
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<pw.Document> generatePDFReport(List<AlarmLog> alarms) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          pw.Header(level: 0, text: 'Modbus Studio Alarm Report'),
          pw.TableHelper.fromTextArray(
            data: alarms.map((a) => [a.timestamp, a.message, a.severity]).toList(),
          ),
        ],
      ),
    ),
  );
  return pdf;
}
```

---

## Testing Strategy
* **Unit Tests**: Rust tests for range-based SQLite log extraction.
* **Widget Tests**: Flutter widget tests verifying date pickers, export dropdowns, and button triggers on the Reports Screen.
* **Mocking**: Mocking the macOS native file-saving dialog to prevent hanging headless test runs.

---

## Boundaries
* **Always**: Apply date filters at the query layer to avoid loading excessive rows into memory.
* **Ask first**: Exposing any new native file system writes outside the standard `~/Documents/ModbusStudio/` directory.
* **Never**: block the main UI thread during report rendering (run PDF generation in an asynchronous isolate or background task).

---

## Success Criteria
* [ ] Operator can select dynamic date range and trigger a native macOS save dialog for both PDF and CSV formats.
* [ ] PDF contains a clean layout showing:
  - Header: Device details and timestamp range.
  - Alarms Section: Table of rule matches with timestamps, severity, and status.
  - Telemetry Section: Table of polled register values.
* [ ] The Javascript QuickJS environment supports a headless `exportReport(format, path)` function which writes the report without GUI prompts.
