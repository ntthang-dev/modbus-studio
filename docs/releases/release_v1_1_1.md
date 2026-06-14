# Modbus Studio v1.1.1 Release Notes & Launch Documentation

Welcome to Modbus Studio v1.1.1! This patch release introduces a fully automated, multi-platform GitHub Actions release pipeline, compiling, packaging, and publishing release artifacts for both Windows and macOS.

---

## 🚀 1. Release Notes (v1.1.1)

### Key Features & Refinements

1. **Multi-Platform Automated Release Workflow**
   - Implemented a parallel build pipeline in [.github/workflows/release.yml](file:///.github/workflows/release.yml) running on `windows-latest` and `macos-latest` runners.
   - Automates the compilation of FFI bindings (`flutter_rust_bridge_codegen`), Rust core library compilation, and Flutter frontend builds.

2. **Windows Release Packaging**
   - Packages the Windows release output folder (renamed to `modbus_studio` to avoid zip bombs) containing `modbus_studio.exe`, `flutter_windows.dll`, and `rust_lib_modbus_studio.dll` as a portable ZIP archive: `modbus_studio_windows.zip`.

3. **macOS Release Packaging**
   - Packages macOS binaries in two formats:
     - **Portable Zip**: Zipped `.app` bundle preserving symlinks and permissions (`zip -r -y`) as `modbus_studio_mac.zip`.
     - **Disk Image**: Native Apple installer (`.dmg`) compiled using macOS's built-in `hdiutil` with a link to `/Applications` for easy drag-and-drop: `modbus_studio_mac.dmg`.

4. **Code Signing and Static Analysis Fixes**
   - Injected environment variables (`CODE_SIGNING_REQUIRED=NO` and `CODE_SIGNING_ALLOWED=NO`) to bypass Xcode codesigning on the headless macOS runner.
   - Excluded the third-party `rust_builder/cargokit/**` directory from the static analyzer in [analysis_options.yaml](file:///Users/ristresso/Developers/modbus_scan/modbus_scada_app/analysis_options.yaml) to keep the pipeline clean of vendor errors.

---

## 📋 2. Pre-Launch Verification

We verified the pipeline and code quality on GitHub Actions:

| Category | Status | Details |
| :--- | :--- | :--- |
| **Code Quality** | 🟩 Green | Staged and committed missing local Dart integration files, resolving previous compilation blocks. All Flutter and Rust tests pass successfully. |
| **Release Artifacts** | 🟩 Green | Verified that all three assets (`modbus_studio_windows.zip`, `modbus_studio_mac.zip`, `modbus_studio_mac.dmg`) compile, zip, and attach correctly to the release. |
| **Security** | 🟩 Green | Enforced narrowest workflow permissions (`contents: write`) and protected token secrets (`${{ secrets.GITHUB_TOKEN }}`). |
| **Code Review** | 🟩 Green | Code review completed and approved in `release_code_review.md`. |
| **GitNexus Index** | 🟩 Green | Pushed rules updates and ran analyze (`✅ up-to-date` status at commit `14f28a2`). |

---

## 🛡️ 3. Rollback Plan

### Trigger Conditions
A rollback of this release is required if:
- Compiled Windows or macOS binaries crash on startup due to FFI translation failures or library mismatches.
- The workflow introduces structural files that break standard developer checkouts.

### Standard Rollback Sequence
1. **Delete/Modify Release**:
   - Run `gh release delete v1.1.1 --yes` using the GitHub CLI to remove the release from the repository.
   - Run `git tag -d v1.1.1` and `git push origin :refs/tags/v1.1.1` to delete the tag from local and remote.
2. **Revert Workflow Changes**:
   - Run `git revert <commit_hash>` to revert pipeline changes if needed, and push to main.

---

## 👁️ 4. Monitoring & Observability

- **Workflow Runs Monitoring**:
  - Track subsequent pipeline compilation logs directly on GitHub Actions under the **Draft Release Build** workflow.
- **Download Verification**:
  - Live public release can be accessed and downloaded here:
    🔗 [Modbus Studio v1.1.1 Releases](https://github.com/ntthang-dev/modbus-studio/releases/tag/v1.1.1)
