# Spec: Dynamic Register Explorer with Format Decoding & Custom Scaling

## Objective
Provide a dynamic and robust Register Explorer interface that enables SCADA operators to read and analyze any Modbus registers (FC01–FC04) by specifying starting addresses and quantities, and format or scale the polled readings individually on a per-register basis using standard data types and custom linear math formulas.

### User Stories
- As a SCADA operator, I want to change the function code (FC01, FC02, FC03, FC04), starting address, and quantity of registers to poll so that I can inspect different device points.
- As a field technician, I want to display raw registers as Int16, Uint16, Int32, Uint32, Float32, Binary, or Hex values (with selectable endianness/word-swapping for 32-bit types) to read multi-register parameters correctly.
- As a technician, I want to set a custom multiplier and offset (e.g. `value * 0.1 - 40`) and suffix unit (e.g. `°C`) for individual registers so that I see real-world sensor measurements rather than raw integers.
- As a user, I expect my display formats and scaling settings to be automatically saved in the database for each register address and restored when I restart the application.

---

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Hooks, Riverpod (`connectionProvider` & a new configuration provider)
- **Native Bridge**: `flutter_rust_bridge` (v2.12.0)
- **Rust Client**: `tokio-modbus` (TCP, RTU, RTU-over-TCP)
- **Local Storage**: SQLite (via `rusqlite` in Rust, accessed via Dart FFI)

---

## Commands
- **Build FFI bindings**: `flutter_rust_bridge_codegen generate`
- **Build App**: `flutter build macos`
- **Run Dev**: `flutter run`
- **Run Tests**: `flutter test`
- **Run Linter**: `flutter analyze`

---

## Project Structure
- `lib/features/registers/register_explorer_screen.dart` (UI & per-register configuration cards)
- `lib/providers/connection_provider.dart` (Exposes connection states and registers list)
- `rust/src/api/client.rs` (Implements new Modbus client read actions)
- `rust/src/api/historian.rs` (Extends historian polling loop to take dynamic FC, address, and quantity)
- `rust/src/api/db.rs` (Implements SQLite table schema and CRUD methods for per-register display settings)

---

## Code Style
### Dart (Cupertino Formats)
```dart
// Custom display converter utility
class RegisterDecoder {
  static String format({
    required List<int> rawRegisters, // 16-bit register words
    required int startIndex,
    required String dataType, // 'Int16', 'Uint16', 'Int32', 'Uint32', 'Float32', 'Binary', 'Hex'
    required bool swapWords,
    double multiplier = 1.0,
    double offset = 0.0,
    String unit = '',
  }) {
    // Decoding logic ...
  }
}
```

### Rust (tokio-modbus usage)
```rust
// In rust/src/api/client.rs
pub async fn read_input_registers(&self, address: u16, quantity: u16) -> anyhow::Result<Vec<u16>> {
    let mut ctx = self.context.lock().await;
    let read_future = ctx.read_input_registers(address, quantity);
    let response = tokio::time::timeout(Duration::from_secs(2), read_future)
        .await
        .map_err(|_| anyhow::anyhow!("Read timeout"))??;
    let data = response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
    Ok(data)
}
```

---

## Testing Strategy
- **Rust Client Unit Tests**: Test each new ModbusClient method (FC01, FC02, FC04) against mock TCP/RTU servers.
- **Flutter Widget Tests**: 
  - Verify that changing the configuration form (dropdowns and address text fields) updates the active poll target.
  - Verify that the per-register configuration dialog allows entering custom scaling parameters (multiplier, offset, units) and formats the output string correctly.
  - Verify that offline/disconnected states render correctly.

---

## Boundaries
- **Always**:
  - Run all widget and unit tests before finalizing features.
  - Apply SQLite database schema changes through backward-compatible migrations.
- **Ask First**:
  - Exposing any new native package dependencies.
- **Never**:
  - Run network I/O or database queries on the Flutter main UI thread.
  - Hardcode Modbus function codes or register count limits.

---

## Success Criteria
- [ ] **Dynamic Polling**: The user can configure the function code (FC01–FC04), starting address, and quantity via the Register Explorer header; changing these settings restarts the polling loop with the new parameters.
- [ ] **Standard Decoders**: The UI decodes and displays values as Int16, Uint16, Int32, Uint32, Float32, Binary (16-bits), and Hex. 32-bit types correctly occupy 2 contiguous registers.
- [ ] **Custom Scaling**: Users can configure linear scaling (`multiplier`, `offset`, and `unit`) per register.
- [ ] **Persistent Display Configuration**: Register display configurations are saved to SQLite and automatically loaded when the register explorer renders.
- [ ] **FFI & Logic Integration**: The Rust client polls coils, discrete inputs, and input registers correctly; raw data is routed back to the Flutter UI stream.
