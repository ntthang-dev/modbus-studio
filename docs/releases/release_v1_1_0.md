# Modbus Studio v1.1.0 Release Notes & Launch Documentation

Welcome to Modbus Studio v1.1.0! This minor release introduces full **Dynamic Register Explorer** configuration, enabling operators to customize Modbus polling query scopes (FC01–FC04) and configure per-register data formatting and linear scaling with persistent database caching.

---

## 🚀 1. Release Notes (v1.1.0)

### Key Features & Refinements

1. **Multi-Type Modbus Polling (FC01, FC02, FC04)**
   - Extended native Rust client in [client.rs](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/rust/src/api/client.rs) to poll Coils (FC01), Discrete Inputs (FC02), and Input Registers (FC04) dynamically.
   - Updated historian stream loop in [historian.rs](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/rust/src/api/historian.rs) to map coil and input booleans (`true` -> `1`, `false` -> `0`) into FFI-compatible data buffers.

2. **Dynamic Poll Range Selector Header**
   - Implemented a premium header configuration card in [register_explorer_screen.dart](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/lib/features/registers/register_explorer_screen.dart) for changing the active Modbus query.
   - Operators can choose the function code, start address, and quantity. Tap **Poll** to securely restart the background historian thread subscription.

3. **Per-Register Data Formatting & Decoding**
   - Created the utility [register_decoder.dart](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/lib/features/registers/register_decoder.dart) to decode raw Modbus words.
   - Supports:
     - `Uint16` (unsigned 16-bit) and `Int16` (signed 16-bit).
     - `Uint32`, `Int32`, and `Float32` (using 2 adjacent registers with selectable word orders).
     - `Hex` (e.g. `0x00FF`), `Binary` (e.g. `0000 1101 0100 0010`), and `Boolean` (e.g. `ON` / `OFF`).

4. **Custom Linear Scaling (`mx + c`)**
   - Added a config dialog on each register tile.
   - Operators can define a **Multiplier**, **Offset**, and **Suffix Unit** (e.g. `°C`, `V`, `PSI`) to convert raw metrics into real-world values.

5. **Persistent Register Configurations**
   - Added a new `register_configs` table in SQLite (`historian.db`) to persist the data type and scaling selections per register.
   - Configs load automatically on reconnecting.

---

## 📋 2. Pre-Launch Checklist

We have verified the health and readiness of the codebase:

| Category | Status | Details |
| :--- | :--- | :--- |
| **Code Quality** | 🟩 Green | 47/47 Flutter and Rust tests passing successfully. Zero static analyze errors. |
| **Security** | 🟩 Green | Clamped register quantities to `1–125` to prevent buffer overflow or device panics. |
| **Performance** | 🟩 Green | Stream restarts dispose of old subscriptions cleanly to prevent memory leaks or thread thrashing. |
| **Accessibility** | 🟩 Green | Large touch targets (>48x48dp), readable units, and text truncation constraints. |
| **Infrastructure** | 🟩 Green | Regenerated FFI bridge bindings using `flutter_rust_bridge_codegen`. |
| **Documentation** | 🟩 Green | Changelog and release notes updated. [AGENTS.md](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/AGENTS.md) rules followed. |

---

## 🛡️ 3. Rollback Plan

### Trigger Conditions
A rollback or hotfix must be initialized if:
- Reconnect/polling configurations cause native socket locks or CPU spikes.
- Writing to registers fails due to FFI translation failures.
- Stored custom scaling configurations cause crashes on database reads.

### Standard Rollback Sequence
1. **Revert Commits**: Run `git revert` on the implementation commits.
2. **Build Downgrade**: Recompile the previous stable code version and distribute DMG.

### Database Compatibility
- If downgraded, the `register_configs` table will remain intact in the SQLite database file, but will simply be ignored by older versions of the app without causing crashes.

---

## 👁️ 4. Observability & Monitoring

1. **Local Rotating Log**:
   - Connection updates and FFI exceptions are logged to:
     `~/Library/Application Support/com.modbus.studio/logs/app.log`

2. **Diagnostician Panel**:
   - Operators can export logs and the database configs via the Settings screen for offline diagnostics.
