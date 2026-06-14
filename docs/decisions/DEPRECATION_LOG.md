# Deprecation and Migration Log

This document records the sunsetting, deprecation, and migration details of legacy systems, modules, and dependencies in Modbus Studio. This context is preserved to explain why the codebase was restructured and to prevent re-implementing deprecated patterns.

---

## 1. Deprecated Systems Summary

All legacy code has been quarantined under the [archive_old_code/](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/archive_old_code/) directory and is excluded from compiler targets, static analysis, and code indexing.

| Legacy System | Path | Replacement | Status | Date Migrated |
| :--- | :--- | :--- | :--- | :--- |
| **Go Modbus Core** | `archive_old_code/core_go/` | Rust Native Core (`rust/`) | Compulsory | 2026-06-13 |
| **Python Scripting** | `archive_old_code/old_python_scripts/` | JS QuickJS Sandbox (`flutter_js`) | Compulsory | 2026-06-13 |
| **Prototype Material UI** | `archive_old_code/gui_flutter/` | Cupertino SCADA Deck (`lib/`) | Compulsory | 2026-06-14 |

---

## 2. Detailed Migration Records

### 2.1 Go Modbus Core (`archive_old_code/core_go/`)
* **Context**: The original Modbus client scanning engine was built in Go, utilizing raw TCP/RTU socket connections.
* **Reason for Deprecation**:
  1. **FFI Toolchain Overhead**: Bundling Go-compiled libraries (`.so`, `.dylib`, `.dll`) into a Flutter application required custom build scripts, manual header parsing, and lacked standard tooling.
  2. **Cross-Compilation Complexity**: Compiling Go for target desktop architectures (especially MSVC targets on Windows and Apple Silicon on macOS) from a unified build pipeline was brittle.
* **Migration Strategy**: 
  * All Modbus TCP and RTU socket code, transaction logs, and SQLite cache engines were ported to Rust (`rust/`).
  * Integrated the Rust codebase into the Flutter build pipeline using `flutter_rust_bridge` version 2.12.0 and `cargokit`, allowing automatic native compilation on standard desktop runners.

### 2.2 Python Automation Scripts (`archive_old_code/old_python_scripts/`)
* **Context**: Legacy SCADA scripts and telemetry reporting functions were handled via external Python scripts triggered shell-side.
* **Reason for Deprecation**:
  1. **Dependency Hell**: Requiring a local Python interpreter, `pip` packages, and native binary libraries on customer SCADA workstations was error-prone and hard to maintain.
  2. **Security Vulnerability**: Shelling out to python scripts broke application sandboxing. Malicious or poorly written user scripts had direct filesystem and network socket access on host SCADA networks.
* **Migration Strategy**:
  * **Automation Scripting**: Replaced the Python automation scripts with a sandboxed QuickJS engine via `flutter_js`, exposing safe, bounded APIs (`Modbus.writeRegister`, `Modbus.logAlarm`) with strict validation rules.
  * **Report Generation**: Replaced Python reporting scripts with native Dart PDF generation (`package:pdf` and `package:printing`), allowing headless generation of PDF and CSV files without host dependency requirements.

### 2.3 Prototype Material GUI (`archive_old_code/gui_flutter/`)
* **Context**: The first prototype dashboard was written in standard Flutter Material widgets.
* **Reason for Deprecation**:
  1. **Aesthetics & HIG**: Standard Material design did not look like professional, premium industrial SCADA software.
  2. **Theme Consistency**: High-stakes control room software requires status-mapped lighting and visual elements tailored for desktop screens, which was hard to achieve using default Material components.
* **Migration Strategy**:
  * Migrated the entire GUI structure to the custom **Liquid Control Deck** design system, implemented via Cupertino native widgets and custom design tokens (located under `lib/features/` and `lib/theme.dart`).
