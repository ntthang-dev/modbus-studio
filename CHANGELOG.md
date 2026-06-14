# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Developer & Copywriter: **ntthang-dev**

---

## [1.0.0] - 2026-06-14

This is the initial production-ready release of Modbus Studio, an industrial-grade Modbus SCADA workstation application built on a Flutter UI and a high-performance native Rust core.

### Added
- **Embedded Javascript Automation Engine**:
  - Sandboxed QuickJS scripting environment (`flutter_js` integration) enabling custom logic execution against live PLC register inputs.
  - Safe UI/Dart log piping and script console displaying run results.
  - Native fallback logic ensuring compilation/testing works in headless CI/CD environments.
- **Compliance & Handover Reports Module**:
  - Implemented a rich graphical Reports Screen featuring dynamic date-range selector cards (Snapshot, 24h, 7d, custom date picker) and format buttons (PDF, CSV).
  - Configured optimized asynchronous SQLite range-based telemetry and alarm history queries in Rust and bridged them to Dart.
  - Integrated native macOS save/share sheet dialog triggers for both PDF and CSV exports.
  - Enabled headless automation exports in the QuickJS sandbox using `Modbus.exportReport(format, rangeHours)` writing to `~/Documents/ModbusStudio/Reports/`.
  - Added robust widget test coverage verifying interactive state selection, layout sizing, and offline error boundaries.
- **SQLite Database & Alarms Integration**:
  - Persistent Alarm Rules with configurable high/low threshold alerts.
  - Alarm logging database engine recording active/resolved status with operator acknowledgment capabilities.
  - Periodic background SQLite database auto-pruning to prevent workstation disk exhaustion.
  - Local database-backed connection profiles saving and favorites tagging.
- **Dynamic SCADA Canvas & Visual Widgets**:
  - Multi-tab drag-and-drop workspace supporting interactive Gauges, Dials, Sliders, and Status Lights.
  - Bidirectional visual controls (sliders/switches) sending Modbus write frames back to hardware devices.
  - Apple Liquid Glass design language integration featuring glassmorphic panels, dark/light themes, and smooth micro-animations.
- **Modbus Protocol Coverage**:
  - Out-of-the-box support for Modbus TCP, Modbus RTU (Serial/USB interfaces), and Modbus RTU-over-TCP.
  - Real-time polling manager using native Rust background threads for latency-free performance.
  - Custom functional code presets for standard coil, discrete input, holding register, and input register addresses.

### Changed
- Refactored `ConnectionNotifier` and local storage providers to share a unified database client lifecycle.
- Optimized telemetry poll intervals with a native thread pool to isolate serial block latencies.
- Standardized UI spacing and navigation layout via a responsive [ResponsiveNavigationShell](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/lib/features/navigation/responsive_navigation_shell.dart).
- **Database Query Optimizations**:
  - Optimized `get_telemetry_logs_by_range` by rewriting the SQLite query to be sargable (removed `strftime` and cast functions from the `WHERE` clause on the `timestamp` column). This allows the query engine to perform O(log N) index range scans rather than full-table scans, drastically reducing cpu/io latency on larger telemetry databases.

### Fixed
- Fixed compilation and syntax errors inside [ConnectionHubScreen](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/lib/features/hub/connection_hub_screen.dart) relating to missing greeting helpers.
- Resolved native QuickJS `.dylib` loading crashes inside headless unit-test runners.
- Repaired database locks by applying WAL mode configurations to SQLite instances.
