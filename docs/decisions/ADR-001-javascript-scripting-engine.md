# ADR-001: Use flutter_js (QuickJS) for Scada Scripting Engine

## Status
Accepted

## Date
2026-06-13

## Context
The Modbus SCADA application requires a way for end-users to write custom automation logic (e.g., if register A > 800, log critical alarm and write to register B).
Key requirements:
- Sandboxed execution (users should not be able to crash the app or access the host filesystem/network directly).
- Fast execution (needs to run frequently on poll ticks, e.g., 10Hz).
- Easy to use language that users are familiar with (JavaScript is ideal).
- Cross-platform support (macOS, Windows, Linux) via Flutter desktop.

## Decision
Use `flutter_js` (which wraps QuickJS) to provide a sandboxed JavaScript runtime.

## Alternatives Considered

### Dart `eval` / `dart:isolate` with dynamic code
- Pros: Native to Flutter, high performance.
- Cons: Dart does not support dynamic code compilation/evaluation in AOT compiled desktop apps.

### Lua (`lua_dardo` or similar)
- Pros: Lightweight, fast, commonly used in game scripting.
- Cons: Less familiar to industrial users compared to JavaScript. Ecosystem and library support in Flutter is weaker than JS.

### WebViews (Invisible iframe)
- Pros: Full JS execution environment.
- Cons: High memory overhead, slow startup, asynchronous boundary is too slow for 10Hz poll tick execution.

## Consequences
- `flutter_js` provides a synchronous, fast QuickJS engine that fits our requirements perfectly.
- We must provide an injected API environment (e.g., `Modbus.getRegister`, `Modbus.writeRegister`, `Modbus.logAlarm`) through the `onMessage` bridge.
- The `flutter_js` library uses native binaries. In headless test environments (`flutter test`), the native engine may crash because Flutter does not load plugins the same way as `flutter run`. This requires us to write a mock engine fallback in `ScriptingNotifier` when `Platform.environment.containsKey('FLUTTER_TEST')` is true.
- *Performance note:* While QuickJS is fast, evaluating a full script string on every 10Hz poll tick is a known performance hotspot. Future optimizations should register a callback and invoke the callback rather than recompiling the user script on every tick.
