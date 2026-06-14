<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **modbus-studio** (2060 symbols, 3653 relationships, 113 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/modbus-studio/context` | Codebase overview, check index freshness |
| `gitnexus://repo/modbus-studio/clusters` | All functional areas |
| `gitnexus://repo/modbus-studio/processes` | All execution flows |
| `gitnexus://repo/modbus-studio/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

## Modbus Studio Development Info

### Tech Stack
- **Frontend**: Flutter (Dart 3.x), Cupertino-native UI library
- **Native Core**: Rust 2021 (custom Modbus TCP/RTU client, SQLite historian database core)
- **FFI Bridge**: `flutter_rust_bridge` v2.12.0
- **Database**: SQLite (local historian telemetry, alarms, profile, and site caching)

### Developer Commands
* **Analyze & Lint**:
  * Flutter: `flutter analyze`
  * Rust: `cargo clippy --manifest-path rust/Cargo.toml -- -D warnings`
* **Run Tests**:
  * Flutter: `flutter test`
  * Rust: `cargo test --manifest-path rust/Cargo.toml`
* **Generate FFI Bindings**:
  * `flutter_rust_bridge_codegen generate`
* **Desktop Builds**:
  * macOS: `flutter build macos --release` (inherits codesign overrides `CODE_SIGNING_REQUIRED=NO` in CI)
  * Windows: `flutter build windows --release`

### Code Conventions & Boundaries
- **UI System**: Cupertino widgets (Liquid Control Deck philosophy). Use Riverpod providers and Flutter hooks (`flutter_riverpod`, `hooks_riverpod`, `flutter_hooks`) for reactive state.
- **Boundary Validation**: Always sanitize and validate untrusted parameters at FFI/Scripting borders (e.g. register address bounds `1–65535`, word values `0–65535`, report paths to prevent traversal).
- **Static Analysis**: Exclude third-party cargokit directory (`rust_builder/cargokit/**`) inside `analysis_options.yaml`.

