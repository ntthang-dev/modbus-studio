# Modbus Studio

A high-performance, edge-ready SCADA diagnostic tool built with Flutter (UI) and Rust (Core Logic). Designed specifically for macOS and iOS with an Apple Liquid Glass aesthetic, Modbus Studio allows field engineers to quickly scan subnets for Modbus TCP devices, read and write registers, and record historical data autonomously.

## Features

- **Radar Auto-Scan:** Asynchronously sweeps subnets (e.g., /24) via a multi-threaded Rust backend, discovering Modbus TCP devices in under 2.5 seconds without blocking the UI.
- **Active Historian (SCADA Engine):** An autonomous background Rust task manages continuous 1-second interval polling, robust reconnection handling, and synchronous SQLite logging.
- **Real-Time Flutter UI:** Uses `flutter_rust_bridge` to funnel background telemetry to the UI via `StreamSink`. Features smooth 60fps glass-morphism designs.
- **Write Operations (FC5 / FC6):** Inject commands directly into registers or coils.
- **Historical Charting:** Visualizes past polled values using `fl_chart`. 

## Architecture

This project is built using `flutter_rust_bridge` (v2).

- **UI Layer (`lib/`):** A strict `CupertinoApp` (no Material) built using Riverpod and flutter_hooks.
- **Core Layer (`rust/src/`):** 
  - `scanner.rs`: Multi-threaded IP sweeper utilizing `tokio-modbus` and `tokio::time`.
  - `client.rs`: Modbus client wrapper for connecting, reading, and writing.
  - `historian.rs`: The SCADA engine loop. Spawns an isolated `tokio` task for continuous operations.
  - `db.rs`: SQLite abstraction. Powered by `rusqlite` using `PRAGMA journal_mode=WAL` to support concurrent read/writes.
  - `mock.rs`: Local dummy server simulating latency and random PLC values for hardware-free development.

## Build Requirements

1. **Flutter SDK** (Channel stable, v3.12+)
2. **Rust Toolchain** (Latest stable)
3. **flutter_rust_bridge_codegen** (v2.12.0+)

## Quick Start

### 1. Generate FFI Bindings
Whenever you modify Rust code inside `rust/src/api/`, you must regenerate the bindings:
```bash
flutter_rust_bridge_codegen generate
```

### 2. Run Locally (Debug)
```bash
flutter run -d macos
```

### 3. Build for Production (Release)
The release build generates a highly optimized executable, strips debug symbols, and applies the transparent native macOS titlebar:
```bash
flutter build macos
```
The executable will be located at:
`build/macos/Build/Products/Release/modbus_studio.app`

## Technical Decisions (ADR)
- **Rust for IO:** Modbus TCP involves strict timeouts and byte parsing. Rust provides memory safety and fearless concurrency for pinging 255 IPs simultaneously.
- **WAL Mode in SQLite:** The active historian writes every 1 second, while the UI reads every 2 seconds. Write-Ahead Logging (WAL) ensures readers never block writers.
- **Native macOS Window:** `MainFlutterWindow.swift` is heavily customized to hide the standard titlebar (`titlebarAppearsTransparent`), allowing the Liquid Glass Flutter theme to stretch edge-to-edge.
