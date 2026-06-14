# ADR-002: Multi-Platform Automated Release Pipeline

## Status
Accepted

## Date
2026-06-15

## Context
Modbus Studio is a cross-platform desktop SCADA application built using Flutter and Rust (`flutter_rust_bridge`). Distributing the application to industrial control operators requires compiled release packages for both Windows and macOS.

Key requirements:
- **Automation**: Release packaging must be repeatable, automatic, and run in CI to eliminate the need for manual compiles on developer machines.
- **Multi-Platform**: Support compiling the Rust FFI library and Flutter frontend for both Windows (`x86_64-pc-windows-msvc`) and macOS (`x86_64` / `aarch64` universal darwin).
- **Packaging Formats**:
  - Windows: Zipped folder containing the `.exe` and all adjacent dynamic libraries (such as `flutter_windows.dll` and `rust_lib_modbus_studio.dll`) without causing "zip bombs" upon extraction.
  - macOS: A portable zipped `.app` bundle and a native `.dmg` (Disk Image) installer with a shortcut link to `/Applications`.
- **Quality Gate**: Releases must be created in a "Draft" state first to allow maintainers to inspect assets and release notes before public launch.

## Decision
Create an automated GitHub Actions release workflow ([.github/workflows/release.yml](file:///.github/workflows/release.yml)) triggered by version tags (e.g., `v*`) or manual execution (`workflow_dispatch`). The workflow compiles the Rust library, builds the Flutter desktop app on native runners (`windows-latest` and `macos-latest`), packages the assets, and uploads them to a GitHub Draft Release using `softprops/action-gh-release@v2`.

## Alternatives Considered

### Manual Builds & Local Distribution
- **Pros**: Easy to configure initially, no CI setup required.
- **Cons**: Requires developer access to separate Windows and macOS physical hardware. Not repeatable, lacks consistency, and introduces risk of local state contamination.
- **Rejected**: Lacks security and does not scale.

### Third-Party NPM Packaging Tools for macOS (e.g., `appdmg`)
- **Pros**: Declarative JSON styling for the DMG mount window.
- **Cons**: Pulls in a heavy tree of NPM and Python build dependencies on the macOS runner, slowing down the CI run and increasing the surface area for dependency failure.
- **Rejected**: Native macOS command line `hdiutil` is extremely fast, built directly into the runner, and has zero external dependencies.

### Inno Setup / MSI Installers for Windows
- **Pros**: Formal wizard installation workflow for Windows.
- **Cons**: Adds complexity to the build pipeline and requires installer authoring scripts. Industrial operators frequently prefer simple portable binaries for control rooms.
- **Rejected**: A zipped release folder containing the `.exe` and its dependencies is cleaner and meets our portability needs. We can add Inno Setup in a future iteration if requested.

## Consequences
- **Repeatable Builds**: Every release is compiled from a clean virtual environment, eliminating local config contamination.
- **Bypassing macOS Code Signing**: Because official signing certificates are not yet configured in CI, macOS builds run with custom environment overrides (`CODE_SIGNING_REQUIRED=NO` and `CODE_SIGNING_ALLOWED=NO`). macOS users will need to bypass Gatekeeper (e.g., Right-Click -> Open) on the first run.
- **Build Times**: Windows builds take ~7 minutes and macOS builds take ~4 minutes due to compilation of the native Rust core library.
- **Artifact Names**: Release files are published as:
  - `modbus_studio_windows.zip` (Windows Portable)
  - `modbus_studio_mac.zip` (macOS Portable)
  - `modbus_studio_mac.dmg` (macOS Installer)
