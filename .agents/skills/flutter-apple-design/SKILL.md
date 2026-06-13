---
name: flutter-apple-design
user-invocable: true
description: >-
  Build Flutter apps with Apple-quality UI following HIG, Liquid Glass philosophy, and Apple Design Award standards.
  Maps SwiftUI patterns to Flutter widgets, Cupertino components, and custom implementations.
  Use when building cross-platform Flutter apps that must feel native on iOS, or when applying Apple design
  principles in Flutter. Coordinates with ios-design-consultant for decisions and ios-ui-craft for visual standards.
---

# Flutter × Apple Design

Build Flutter apps that feel genuinely Apple-native — not "cross-platform ports." This skill translates
the full Apple design system (HIG, Liquid Glass philosophy, award-worthy aesthetics) into Flutter/Dart
implementations using Cupertino widgets, custom effects, and platform-adaptive patterns.

## When to Use

- Building a Flutter app that must feel native on iOS
- Applying Apple HIG / Liquid Glass design principles in Flutter
- Converting SwiftUI designs or mockups into Flutter
- Creating cross-platform apps where iOS is the primary design target
- Reviewing Flutter UI for Apple-quality compliance

## Dependencies

These skills provide the design foundation — read them first for design decisions:

| Skill | Role |
|-------|------|
| `/ios-design-consultant` | UX and layout decisions (glass decisions, positioning, hierarchy) |
| `/ios-ui-craft` | Visual quality standards, anti-patterns, award-worthy checklist |
| `/ios-liquid-glass` | Liquid Glass API concepts to translate into Flutter equivalents |
| `/ios-dev` | Correctness principles and topic routing |
| `/macos-design` | macOS-native patterns when targeting desktop |

## Core Philosophy

### The Translation Principle

> Don't port SwiftUI code line-by-line. Translate the **design intent** and **user experience**
> into Flutter's widget paradigm while preserving Apple's aesthetic standards.

### Three Rules

1. **Cupertino First** — Use `CupertinoApp`, `CupertinoNavigationBar`, `CupertinoTabBar`,
   `CupertinoButton`, `CupertinoTextField`, etc. as defaults. Only fall back to Material
   when Cupertino has no equivalent.
2. **Platform-Adaptive** — Use `Platform.isIOS` checks and adaptive widgets for
   cross-platform features. iOS should feel iOS-native, Android should feel Android-native.
3. **Apple Quality Bar** — Apply the same anti-patterns checklist from `/ios-ui-craft`.
   No purple gradients. No flat interactions. No system fonts everywhere. Typography hierarchy,
   spring animations, haptics, dark mode first.

## SwiftUI → Flutter Widget Mapping

### Navigation

| SwiftUI | Flutter Equivalent |
|---------|--------------------|
| `NavigationStack` | `CupertinoNavigationBar` + `Navigator 2.0` or `go_router` |
| `TabView` | `CupertinoTabBar` + `CupertinoTabScaffold` |
| `.sheet()` | `showCupertinoModalPopup()` or `CupertinoPageRoute` |
| `.navigationTitle()` | `CupertinoSliverNavigationBar` (large title) |
| `NavigationSplitView` | `CupertinoSplitView` (custom) or adaptive layout |

### Controls

| SwiftUI | Flutter Equivalent |
|---------|--------------------|
| `Button` | `CupertinoButton` |
| `Toggle` | `CupertinoSwitch` |
| `Slider` | `CupertinoSlider` |
| `Picker` | `CupertinoPicker` / `CupertinoSegmentedControl` |
| `TextField` | `CupertinoTextField` |
| `DatePicker` | `CupertinoDatePicker` |
| `Alert` | `CupertinoAlertDialog` |
| `ActionSheet` | `CupertinoActionSheet` |
| `ProgressView` | `CupertinoActivityIndicator` |
| `SearchBar` | `CupertinoSearchTextField` |

### Layout

| SwiftUI | Flutter Equivalent |
|---------|--------------------|
| `VStack` | `Column` |
| `HStack` | `Row` |
| `ZStack` | `Stack` |
| `ScrollView` | `SingleChildScrollView` / `CustomScrollView` |
| `List` | `CupertinoListSection` + `CupertinoListTile` |
| `LazyVGrid` | `GridView` / `SliverGrid` |
| `GeometryReader` | `LayoutBuilder` |
| `Spacer` | `Spacer` / `Expanded` |
| `.padding()` | `Padding` widget or `EdgeInsets` |

### State Management (Conceptual)

| SwiftUI | Flutter Equivalent |
|---------|--------------------|
| `@State` | `setState()` or `ValueNotifier` |
| `@Binding` | Callback functions + parent state |
| `@Observable` | `ChangeNotifier` / `Riverpod` / `Bloc` |
| `@Environment` | `InheritedWidget` / `Provider` / `Riverpod` |
| `.task {}` | `initState()` + `FutureBuilder` or hooks |
| `.onChange(of:)` | `didUpdateWidget()` or reactive streams |

## Liquid Glass Translation

Liquid Glass cannot be replicated 1:1 in Flutter, but the **philosophy** applies:

### Glass Effect in Flutter

```dart
// Frosted glass / blur effect (approximates .regular glass)
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.separator.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: child,
    ),
  ),
);
```

### Glass Principles in Flutter

| Liquid Glass Principle | Flutter Implementation |
|------------------------|----------------------|
| Glass for controls only | Apply `BackdropFilter` to nav bars, toolbars, FABs — never content cards |
| Content beneath glass | Use `Stack` with content layer below glass layer |
| Morphing transitions | Use `Hero` widget + custom `PageRouteBuilder` |
| Interactive glass | Add `GestureDetector` with scale animations on press |
| Concentric corners | Match `borderRadius` to container hierarchy |

## Typography System

```dart
// Create Apple-quality typography hierarchy
class AppTypography {
  // Display — for headers and hero text
  static const display = TextStyle(
    fontFamily: '.SF Pro Display',  // Falls back to system on iOS
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.37,
  );

  // Title
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.36,
  );

  // Headline
  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
  );

  // Body
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.normal,
    letterSpacing: -0.41,
  );

  // Caption
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    color: CupertinoColors.secondaryLabel,
  );
}
```

## Animation Standards

```dart
// Spring/bouncy is the Apple default — replicate in Flutter
// Use spring simulation instead of linear/ease curves
final springAnimation = SpringSimulation(
  SpringDescription(mass: 1, stiffness: 300, damping: 20),
  0, 1, 0,
);

// Or use Curves.elasticOut for quick approximation
AnimatedContainer(
  duration: Duration(milliseconds: 400),
  curve: Curves.elasticOut,  // Bouncy feel
  child: child,
);

// For button press feedback (scale to 0.95, spring back)
GestureDetector(
  onTapDown: (_) => setState(() => _scale = 0.95),
  onTapUp: (_) => setState(() => _scale = 1.0),
  onTapCancel: () => setState(() => _scale = 1.0),
  child: AnimatedScale(
    scale: _scale,
    duration: Duration(milliseconds: 150),
    curve: Curves.easeOutBack,
    child: child,
  ),
);
```

## Haptics in Flutter

```dart
import 'package:flutter/services.dart';

// Light impact (button tap)
HapticFeedback.lightImpact();

// Medium impact (toggle, significant action)
HapticFeedback.mediumImpact();

// Heavy impact (destructive action)
HapticFeedback.heavyImpact();

// Selection changed (picker, slider)
HapticFeedback.selectionClick();
```

## Dark Mode First

```dart
// Design for dark mode first, then adapt
CupertinoApp(
  theme: CupertinoThemeData(
    brightness: Brightness.dark,  // Dark first
    primaryColor: CupertinoColors.systemBlue,
    scaffoldBackgroundColor: CupertinoColors.black,
    textTheme: CupertinoTextThemeData(
      primaryColor: CupertinoColors.white,
    ),
  ),
);

// Use CupertinoColors for automatic dark/light adaptation
CupertinoColors.systemBackground    // Adapts automatically
CupertinoColors.label               // Adapts automatically
CupertinoColors.secondaryLabel      // Adapts automatically
CupertinoColors.separator           // Adapts automatically
```

## Quality Checklist (Flutter Edition)

Before considering Flutter UI complete:

- [ ] Using `CupertinoApp` (not `MaterialApp`) for iOS-primary apps
- [ ] Cupertino widgets for all standard controls
- [ ] `BackdropFilter` glass effects on controls layer only — never on content
- [ ] Haptics on all meaningful interactions (`HapticFeedback`)
- [ ] Spring/bouncy animations — not linear curves
- [ ] SF Symbols via `cupertino_icons` package (not random icon packs)
- [ ] Dark mode tested and polished — dark first design
- [ ] Typography hierarchy clear and intentional — SF Pro sizing
- [ ] Colors purposeful — `CupertinoColors` with dominant + accent strategy
- [ ] `Hero` morphing transitions where applicable
- [ ] Loading states animated (`CupertinoActivityIndicator`)
- [ ] Empty states designed
- [ ] Error states helpful and styled
- [ ] Platform-adaptive where needed (`Platform.isIOS`)
- [ ] Screenshot taken and visually verified
- [ ] Passes Apple design anti-patterns check (no AI slop)

## Anti-Patterns in Flutter (Apple Context)

| ❌ Don't | ✅ Do |
|----------|-------|
| Use `MaterialApp` for iOS-primary | Use `CupertinoApp` |
| Material icons on iOS | `cupertino_icons` package |
| `ElevatedButton` on iOS | `CupertinoButton` |
| Material `SnackBar` | `CupertinoAlertDialog` or toast |
| `CircularProgressIndicator` on iOS | `CupertinoActivityIndicator` |
| `AppBar` on iOS | `CupertinoNavigationBar` |
| `BottomNavigationBar` on iOS | `CupertinoTabBar` |
| Default `ThemeData` colors | `CupertinoThemeData` with curated palette |
| `Curves.easeInOut` everywhere | `Curves.elasticOut` / spring simulations |

## Recommended Packages

| Package | Purpose |
|---------|---------|
| `cupertino_icons` | SF Symbol equivalents |
| `go_router` | Declarative routing (NavigationStack equivalent) |
| `flutter_riverpod` | State management (SwiftUI @Observable equivalent) |
| `flutter_animate` | Declarative animations (spring, stagger, shimmer) |
| `modal_bottom_sheet` | iOS-style modal sheets |
| `pull_to_refresh_flutter3` | iOS-native pull to refresh |
| `shimmer` | Loading state shimmer effects |

## Workflow

### New Flutter App with Apple Design

1. Consult `/ios-design-consultant` for UX decisions
2. Setup `CupertinoApp` with dark-first theming
3. Build navigation with `CupertinoTabScaffold` + `go_router`
4. Implement glass effects with `BackdropFilter` for controls layer
5. Apply typography hierarchy with SF Pro sizing
6. Add spring animations and haptic feedback
7. Test dark mode, then adapt light mode
8. Run quality checklist above
9. Screenshot and iterate until award-worthy

### Converting SwiftUI → Flutter

1. Read the SwiftUI code and identify **design intent** (not just widgets)
2. Map each SwiftUI view to Flutter equivalent using tables above
3. Translate state management pattern (not 1:1, but conceptually)
4. Apply glass effects using `BackdropFilter` philosophy
5. Preserve animation timing and spring curves
6. Test on iOS simulator — should feel indistinguishable from native

## Related Skills

- `/ios-design-consultant` — Design decisions before coding
- `/ios-ui-craft` — Visual quality standards to match
- `/ios-liquid-glass` — Glass API concepts to translate
- `/ios-dev` — Correctness principles
- `/apple-product-workflow` — Full product design → Flutter pipeline
