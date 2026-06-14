# Spec: Phase 2 — Core Modbus Protocol Expansion

## Objective
Support advanced industrial connectivity options in Modbus Studio: Modbus RTU (Serial), RTU over TCP (encapsulated), and Modbus ASCII. Persistently store connection profiles (target IP, port, serial ports, baud rates, parity) in a local SQLite table managed by the Rust backend. Enable engineers to configure and scan multiple device setups seamlessly across desktop (macOS/Windows) and mobile (iOS/iPadOS) systems.

## Tech Stack
* **Language & Framework**: Dart/Flutter (Cupertino widgets) & Rust (backend logic).
* **Communication Bridging**: `flutter_rust_bridge` (v2.12.0) for IPC data serialization.
* **Modbus Backend**: Rust `tokio_modbus` (v0.17.0) with the `rtu` feature flag enabled.
* **Serial Port Communication**: `tokio-serial` (transitive dependency under `tokio_modbus/rtu`).
* **Database**: `rusqlite` (v0.40.1) for local connection profiles and register logging.

## Commands
* **Build App**: `flutter build macos` / `flutter build windows`
* **Run App**: `flutter run`
* **Generate Rust Bridges**: `flutter_rust_bridge_codegen generate`
* **Test Rust Backend**: `cargo test` (inside `rust/` directory)
* **Test Flutter Frontend**: `flutter test`

## Project Structure
```
lib/providers/connection_provider.dart      → Managed global connection state
lib/features/hub/connection_hub_screen.dart → Hub dashboard UI
rust/src/api/client.rs                      → Modbus client implementation (TCP/RTU)
rust/src/api/db.rs                          → SQLite client schemas and helpers
rust/src/api/historian.rs                   → Background worker logging loop
rust/Cargo.toml                             → Rust project dependencies and features
docs/specs/                                 → Specifications and engineering docs
```

## Code Style
### Rust Interface (Bridge Contract)
```rust
#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub enum ConnectionType {
    Tcp { ip: String, port: u16 },
    RtuOverTcp { ip: String, port: u16 },
    Serial {
        port_name: String,
        baud_rate: u32,
        parity: String, // "None", "Even", "Odd"
        data_bits: u8,
        stop_bits: u8,
    },
    Ascii {
        port_name: String,
        baud_rate: u32,
    }
}

#[derive(Clone)]
pub struct ConnectionProfile {
    pub id: Option<i64>,
    pub name: String,
    pub config: ConnectionType,
    pub is_favorite: bool,
    pub last_used: i64, // Unix timestamp
}
```

## Testing Strategy
1. **Unit Tests**:
   * Rust `db.rs` tests for inserting, listing, deleting, and updating `connection_profiles`.
   * Dart `connection_provider_test.dart` for handling state transitions during TCP, RTU, and Serial connections.
2. **Integration Tests**:
   * Mocking TCP/RTU server sockets using Rust's `tokio::net::TcpListener` to verify that `tokio_modbus` establishes connections and parses frame exceptions correctly.

## Boundaries
* **Always**: 
  * Validate serial configurations (baud rates between 300 and 921600; parity matches standard enumerations) before invoking Rust connections.
  * Close previous connections and active DB log loops before initializing a new connection.
* **Ask first**:
  * Modifying `rust/Cargo.toml` dependencies or adding native serial plugin libraries to the Flutter root.
* **Never**:
  * Block the Flutter main thread (UI thread) with synchronous serial port reads/writes; all transactions must run inside tokio background tasks in Rust.

## Success Criteria
* [ ] The `tokio-modbus` dependency compiles successfully with the `rtu` features enabled.
* [ ] The SQLite database `historian.db` successfully creates the `connection_profiles` table on initialization.
* [ ] Connection profiles can be successfully created, deleted, and queried through the Flutter interface, communicating via the Rust bridge.
* [ ] RTU over TCP connections successfully decode holding registers 40001–40010 and write single registers.
* [ ] Serial RTU setups successfully initiate on desktop platforms using standard port configurations.
* [ ] Code compiles cleanly and all unit/integration tests pass.

## Open Questions
* **USB-to-Serial Platform channels**: What specific iOS/Android serial library will be used to bridge standard USB interfaces on sandboxed mobile setups? *(Draft plan: Leverage `flutter_libserialport` or custom native Swift/Java interfaces in a future phase; standard desktop setups will run directly on standard Rust serial plugins).*
