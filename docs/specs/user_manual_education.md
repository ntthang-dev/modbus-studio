# Spec: Modbus Protocol Educational Content in User Manual

## Objective
Enhance the "Modbus Basics" tab in the User Manual screen (or introduce a new "Modbus Knowledge" tab) to provide a clear, beginner-friendly educational guide about the Modbus protocol, Modbus TCP, and Modbus RTU.

### Requirements & Educational Scope
1. **What is Modbus?**
   - High-level overview: Created by Modicon in 1979; an open, simple query-response industrial protocol.
   - Master-Slave / Client-Server concept: Who initiates commands, who responds.
2. **Modbus Protocol Frame Structure**:
   - Explanation of ADU (Application Data Unit) and PDU (Protocol Data Unit).
   - Role of Function Codes (FC01 - FC04) and register addresses.
3. **Modbus RTU (Serial)**:
   - Transport: RS-485, RS-232, USB-Serial.
   - Encoding: Compact binary, trailing CRC (Cyclic Redundancy Check) for error checking.
   - Core concepts: Baud rate, Parity, Stop bits, Slave ID (1-247).
4. **Modbus TCP (Ethernet)**:
   - Transport: Standard Ethernet networks, TCP/IP stack.
   - Port: Standard port 502.
   - Headers: MBAP (Modbus Application Protocol) header, transaction ID replacing slave ID (unit ID is still used for bridging).
5. **Core Differences Comparison**:
   - Compare RTU vs TCP in a clear comparison card or table (speed, distance, hardware, error checking).

---

## Tech Stack
- **Framework**: Flutter (Cupertino)
- **Language**: Dart
- **Design System**: Liquid Control Deck (dark mode, custom formatted cards, lists, tables)

---

## Commands
- Run: `flutter run`
- Test: `flutter test test/features/manual/user_manual_screen_test.dart`
- Lint: `flutter analyze`

---

## Project Structure
- Modified files:
  - `lib/features/manual/user_manual_screen.dart` (Add more educational content widgets, tabs, or sections)
  - `test/features/manual/user_manual_screen_test.dart` (Update checks for new keywords)

---

## Testing Strategy
- Update the widget test in `test/features/manual/user_manual_screen_test.dart` to assert that the terms: "Modbus TCP", "Modbus RTU", "MBAP", "CRC", "RS-485", and "Master-Slave" render when the educational sections are loaded.

---

## Success Criteria
- [ ] Users can browse detailed explanations of Modbus TCP and Modbus RTU.
- [ ] A comparison table/card showing differences between Modbus RTU and Modbus TCP is rendered.
- [ ] All widget tests run and pass cleanly.
- [ ] Static analysis contains zero errors or warnings on changed files.
