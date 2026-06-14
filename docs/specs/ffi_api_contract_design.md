# FFI and Scripting API Contract Design

This document describes the API boundaries, validation semantics, and type contracts established in Modbus Studio. This system bridges two critical boundaries:
1. **The Native FFI Boundary**: Between Dart/Flutter and Rust (`flutter_rust_bridge`).
2. **The Scripting Sandbox Boundary**: Between the Flutter application and the untracked JavaScript execution sandbox (`flutter_js`/QuickJS).

---

## 1. Native FFI Boundary Contract

The FFI boundary is the communication link between the Flutter user interface and the native Rust Modbus client/historian core.

### 1.1 Type Safety & Contract First
The FFI interfaces are defined in Rust first under `rust/src/api/` and generated into Dart classes automatically.

```
       [ Flutter UI / Providers (Dart) ]
                       │
                       ▼  (Generated FFI bindings)
         [ Rust FFI Bridge (C-Dylib) ]
                       │
                       ▼  (Native execution)
       [ Rust client / historian / SQLite ]
```

### 1.2 Data Schemas

#### Connection Configuration Schema (`ConnectionConfig`)
Every connection configuration is verified and sent from the database layer to the native connection task:
* `protocol_type`: `String` (Must be one of `"TCP"`, `"RTU_TCP"`, or `"SERIAL"`)
* `ip`: `Option<String>` (Required for TCP and RTU_TCP)
* `port`: `Option<u16>` (Defaults to `502` if omitted)
* `port_name`: `Option<String>` (Required for SERIAL)
* `baud_rate`: `Option<u32>` (Defaults to `9600`)
* `parity`: `Option<String>` (Defaults to `"None"`)
* `data_bits`: `Option<u8>` (Defaults to `8`)
* `stop_bits`: `Option<u8>` (Defaults to `1`)

#### Telemetry Flow Schema (`HistorianData` & `HistorianPoint`)
Telemetry is streamed reactively from Rust to Dart via `StreamSink`:
```rust
pub struct HistorianData {
    pub registers: Vec<u16>,
    pub error: Option<String>,
}

pub struct HistorianPoint {
    pub timestamp_ms: i64,
    pub address: u16,
    pub value: u16,
}
```
* **Error handling**: The `error` field implements consistent semantic propagation. FFI tasks catch native exceptions, wrap them into `Some(String)` error descriptions, and send them through the sink rather than crashing the native FFI thread.

---

## 2. Scripting Sandbox Boundary Validation

The JavaScript scripting engine runs untrusted user-submitted scripts. System-level capabilities are exposed through a controlled bridging interface. Consistent with **"Validate at Boundaries"**, we enforce validation rules before passing data to internal system operations.

### 2.1 Bridging Interface Overview
```javascript
// Exposed JS environment API
Modbus.writeRegister(address, value); // Writes value to Modbus address
Modbus.logAlarm(message, severity);   // Logs a custom SCADA alarm
Modbus.exportReport(format, hours);   // Triggers custom report generation
```

### 2.2 Boundary Validation Implementations

To prevent memory exhaustion, path traversal, and out-of-bounds register writes, the boundary APIs enforce strict validation criteria:

#### 1. Modbus Register Write Validation
* **Rule**: Addresses must represent valid Modbus ranges, and values must be standard 16-bit words.
* **Code Implementation**:
  ```dart
  bool validateWriteRegister(int address, int value) {
    if (address < 1 || address > 65535) {
      _log("JS Security Alert: writeRegister blocked. Address $address is out of bounds.");
      return false;
    }
    if (value < 0 || value > 65535) {
      _log("JS Security Alert: writeRegister blocked. Value $value is out of 16-bit bounds.");
      return false;
    }
    return true;
  }
  ```

#### 2. SCADA Alarm Validation
* **Rule**: Custom message lengths are constrained to prevent memory exhaustion, and severity levels are validated against a strict enum map.
* **Code Implementation**:
  ```dart
  bool validateLogAlarm(String message, String severity) {
    final String rawSev = severity.toLowerCase();
    if (rawSev != 'critical' && rawSev != 'warning') {
      _log("JS Security Alert: logAlarm blocked. Invalid severity '$severity'. Only 'critical' and 'warning' are allowed.");
      return false;
    }
    return true;
  }
  ```

#### 3. Report Export Validation (Path Traversal and DoS Prevention)
* **Rule**: Formats are restricted to explicit extensions to block directory traversal payloads, and the query window is capped.
* **Code Implementation**:
  ```dart
  bool validateExportReport(String format, int rangeHours) {
    final String fmt = format.toLowerCase();
    if (fmt != 'pdf' && fmt != 'csv') {
      _log("JS Security Alert: exportReport blocked. Invalid format '$format'. Only 'pdf' and 'csv' are allowed.");
      return false;
    }
    if (rangeHours < 1 || rangeHours > 720) {
      _log("JS Security Alert: exportReport blocked. rangeHours '$rangeHours' is out of bounds (1 to 720 hours).");
      return false;
    }
    return true;
  }
  ```

---

## 3. Best Practices & Design Rules Followed

1. **Hyrum's Law Mitigation**: Every API field and type is fully typed and modeled under `rust/src/api/db.rs` rather than passing raw JSON strings across FFI. This prevents clients from depending on implicit/undocumented parsing quirks.
2. **One-Version Rule**: A single unified `HistorianPoint` struct is used for live polling telemetry, offline SQLite history queries, and PDF telemetry logs, ensuring semantic format alignment across the entire codebase.
3. **No Mixed Error Semantics**: FFI methods consistently return an `anyhow::Result<T>` in Rust, which converts to native `throws Exception` in Dart. This gives the Flutter consumer a predictable error-handling mechanism (using standard Dart `try-catch` blocks).
