# Spec: User Manual & Changelog Screen

## Objective
Introduce a dedicated "User Manual" screen within Modbus Studio. The screen serves as an on-device reference for field operators and developers to understand the workstation's capabilities, review the system changelog, and view the developer licensing/copyright notices.

### User Stories & Requirements
- As an operator, I want to access a simple, offline user manual tab from the sidebar to learn how to scan, poll, and automate Modbus devices.
- As an operator, I want to see a clear changelog showing what features were added in each release (v1.0.0, v1.0.1, v1.1.0).
- As a user/developer, I want to see the clear copyright and usage guidelines from the developer **ntthang-dev (ぞたの)**.

---

## Tech Stack
- **Framework**: Flutter (Cupertino widgets)
- **Language**: Dart
- **Design System**: Liquid Control Deck (dark mode, glassmorphic panels, status-mapped glow elements, customized scroll views)

---

## Commands
- Run Flutter App: `flutter run`
- Test: `flutter test test/features/manual/user_manual_screen_test.dart`
- Lint/Analyze: `flutter analyze`

---

## Project Structure
- Screen file: `lib/features/manual/user_manual_screen.dart`
- Unit/Widget test: `test/features/manual/user_manual_screen_test.dart`
- Routing & Navigation update:
  - `lib/providers/ui_provider.dart` (Add `manual` enum value to `AppScreen`)
  - `lib/features/navigation/responsive_navigation_shell.dart` (Add navigation item and screen case mapping)

---

## Code Style & Layout Design
The manual will use a split pane or custom tabbed UI in the Liquid Control Deck style:
- Left sub-menu: Categorized topics ("Getting Started", "Modbus Basics", "Scripting Guides", "Changelog", "License & Copyright").
- Right pane: Beautifully padded, scrollable content card with high-readability typography, monospace sections for APIs/configs, and subtle ambient glows.
- Minimal Touch Target: All sub-menu links have a height of `48pt`.

Example Cupertino/Flutter style for the view:
```dart
CupertinoListTile(
  title: Text('Changelog', style: TextStyle(color: CupertinoColors.white)),
  leading: Icon(CupertinoIcons.doc_text_fill, color: CupertinoColors.systemTeal),
  onTap: () => activeSection.value = ManualSection.changelog,
)
```

---

## Testing Strategy
- **Widget Test**: Validate rendering of the sub-menu options and verifying page-content changes when tapping different tabs.
- Location: `test/features/manual/user_manual_screen_test.dart`.

---

## Boundaries
- **Always**:
  - Keep styling aligned with dark Liquid Control Deck theme.
  - Expose copyright prominently under the "License & Copyright" section.
  - Verify accessibility contrast ratios and touch target targets (>44x44pt).
- **Ask First**:
  - Adding external markdown rendering libraries (prefer built-in Cupertino rich text layout to avoid bloat).
- **Never**:
  - Exclude copyright mentions for `ntthang-dev (ぞたの)`.

---

## Success Criteria
- [ ] Added `AppScreen.manual` tab to UI and navigation sidebar.
- [ ] User Manual screen renders without overflow or rendering issues.
- [ ] Users can browse "Getting Started", "Modbus Basics", "Scripting Engine", "Changelog", and "Copyright" tabs.
- [ ] Under the copyright tab, the exact text acknowledging **ntthang-dev (ぞたの)** is shown.
- [ ] All tests compile and pass successfully.
