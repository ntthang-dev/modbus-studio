---
name: apple-product-workflow
user-invocable: true
description: >-
  End-to-end product design pipeline: idea → design → build → test → publish.
  Orchestrates all Apple skills and Flutter bridge in optimal sequence.
  Use when starting a new app project from scratch, running a full product design sprint,
  or when you need the fastest path from concept to published app using all available skills.
---

# Apple Product Workflow — Full Pipeline Orchestrator

One command to rule them all. This skill orchestrates the entire product design-to-publish
pipeline by calling the right skills at the right time, in the right order.

## When to Use

- Starting a brand new iOS or Flutter app from zero
- Running a design sprint for a product feature
- Need the fastest path from idea → published app
- Want a structured workflow that uses ALL available skills efficiently
- Converting an existing design to implementation (native or Flutter)

## Dependencies

This skill orchestrates — it doesn't replace. It calls these skills in sequence:

| Phase | Skills Used |
|-------|-------------|
| Vision | `/steve-jobs`, `/ios-design-consultant` |
| Architecture | `/ios-dev`, `/guide-swiftui-ui-patterns`, `/guide-swiftdata` |
| Build (Native) | `/ios-ui-craft`, `/ios-liquid-glass`, `/guide-swiftui-animations` |
| Build (Flutter) | `/flutter-apple-design` |
| Framework Integration | `/healthkit`, `/mapkit`, `/storekit`, `/widgetkit`, `/usernotifications`, `/eventkit`, `/appintents` |
| Polish | `/guide-swiftui-view-refactor`, `/guide-swiftui-performance-audit`, `/macos-design` |
| Test | `/xcuitest` |
| Publish | `/apple-aso`, `/guide-macos-spm-packaging` |
| Reference | `/apple-docs-index`, `/uikit`, `/core-animation` |
| Compliance | `/iso-13485-certification` (if medical device) |

## Quick Start

Tell me what you want to build, and I'll run the full pipeline:

```
"Tôi muốn xây dựng một ứng dụng [mô tả] với [nền tảng: iOS native / Flutter / macOS]"
```

I will automatically:
1. Validate the idea through Steve Jobs' product lens
2. Make all design decisions using Apple HIG
3. Build with the right tech stack
4. Polish to award-worthy quality
5. Prepare for publishing

## The Pipeline

### Phase 0: Intake & Platform Decision

**Input:** Product idea, target users, platform preference

**Decision Tree:**

```
Is this iOS only?
├── YES → Native SwiftUI path (Phase 1A)
├── NO → Is iOS the primary platform?
│   ├── YES → Flutter with Cupertino-first (Phase 1B)
│   └── NO → Flutter with adaptive design (Phase 1B)
└── Is this macOS?
    └── YES → SwiftUI + /macos-design + /guide-macos-spm-packaging
```

**Output:** Chosen tech stack, platform strategy

---

### Phase 1: Product Vision (30 min)

**Skills:** `/steve-jobs` → `/ios-design-consultant`

**Steps:**

1. **Product Critique** (`/steve-jobs`)
   - What problem does this solve?
   - Who is the user? What do they feel?
   - What's the "one thing" that makes this memorable?
   - Would Steve buy this? If not, why?
   - "Shoot the puppy" test — is this worth building?

2. **Design Direction** (`/ios-design-consultant`)
   - Choose aesthetic tone: calm, playful, premium, editorial, utilitarian
   - Glass strategy: where does glass frame content vs. compete with it?
   - Navigation model: tabs, stack, split, sidebar?
   - Color strategy: dominant + accent, dark mode first
   - Key screens identification

**Output:** Product brief, design direction document, key screens list

---

### Phase 2: Architecture (20 min)

**Skills:** `/ios-dev` → `/guide-swiftui-ui-patterns` → `/guide-swiftdata`

**Steps:**

1. **Project Setup** (`/ios-dev`)
   - Run Correctness Checklist for planned patterns
   - Identify which framework skills will be needed
   - Set up topic routing for the project

2. **State & Navigation Architecture** (`/guide-swiftui-ui-patterns`)
   - Define state ownership model
   - Wire TabView + NavigationStack + sheets
   - Setup AppTab enum and RouterPath
   - Plan async data flow with `.task`

3. **Data Layer** (`/guide-swiftdata`)
   - Design data models
   - Define relationships and delete rules
   - Plan CloudKit sync if needed (optional fields, no #Unique)
   - Setup indexing strategy (iOS 18+)

**Output:** Architecture diagram, state ownership map, data model design

---

### Phase 3A: Build — Native SwiftUI

**Skills:** `/ios-ui-craft` → `/ios-liquid-glass` → `/guide-swiftui-animations`

**Steps:**

1. **UI Implementation** (`/ios-ui-craft`)
   - Build each screen with award-worthy quality
   - Screenshot-driven iteration loop
   - Apply anti-patterns checklist
   - Dark mode first, light mode adapt

2. **Glass Effects** (`/ios-liquid-glass`)
   - Apply `.regular` glass to navigation/controls
   - Use `.clear` for floating controls over media
   - Setup morphing transitions with `GlassEffectContainer`
   - Add `glassEffectID` for namespace-based morphing

3. **Motion Design** (`/guide-swiftui-animations`)
   - Spring/bouncy as default animation curve
   - Morph between states, don't swap
   - Staggered list appearances
   - SF Symbol draw animations
   - Haptics on every meaningful interaction

**Output:** Production-ready UI code, screenshots

---

### Phase 3B: Build — Flutter

**Skills:** `/flutter-apple-design` ← (`/ios-design-consultant` + `/ios-ui-craft`)

**Steps:**

1. **Setup CupertinoApp** (`/flutter-apple-design`)
   - Dark-first theming with `CupertinoThemeData`
   - Font stack with SF Pro sizing
   - `CupertinoColors` for automatic dark/light adaptation

2. **Navigation** (`/flutter-apple-design`)
   - `CupertinoTabScaffold` + `go_router`
   - `CupertinoNavigationBar` with large titles
   - Modal sheets with `showCupertinoModalPopup()`

3. **Glass Effects** (`/flutter-apple-design`)
   - `BackdropFilter` for controls layer
   - `ClipRRect` + blur for frosted glass
   - `Hero` widget for morphing transitions

4. **Visual Polish** (apply `/ios-ui-craft` standards)
   - Typography hierarchy
   - Spring animations with `Curves.elasticOut`
   - `HapticFeedback` on interactions
   - Screenshot and iterate

**Output:** Production-ready Flutter code, iOS simulator screenshots

---

### Phase 4: Framework Integration (as needed)

**Skills:** Select based on features needed

| Feature | Skill | Notes |
|---------|-------|-------|
| Health data | `/healthkit` | HKHealthStore, quantity samples |
| Maps | `/mapkit` | Map view, markers, annotations |
| Payments | `/storekit` | StoreKit 2, subscriptions |
| Widgets | `/widgetkit` | Home/lock screen widgets |
| Notifications | `/usernotifications` | Local/remote triggers |
| Calendar | `/eventkit` | Events, reminders |
| Siri/Shortcuts | `/appintents` | AppIntent, AppShortcut |
| UIKit bridging | `/uikit` | UIHostingController, UIView |
| Particle effects | `/core-animation` | CAEmitterLayer, CAShapeLayer |

For Flutter: Use platform channels to access native iOS framework APIs,
or use equivalent Flutter packages (e.g., `health`, `google_maps_flutter`, `in_app_purchase`).

**Output:** Integrated framework features, tested

---

### Phase 5: Polish & Refactor (15 min)

**Skills:** `/guide-swiftui-view-refactor` → `/guide-swiftui-performance-audit`

**Steps:**

1. **Code Structure** (`/guide-swiftui-view-refactor`)
   - Split views > 300 lines into subviews
   - Extract dedicated `View` types (not computed properties)
   - Move business logic out of `body`
   - Enforce MV-over-MVVM pattern
   - Validate `@Observable` usage

2. **Performance** (`/guide-swiftui-performance-audit`)
   - Check for invalidation storms
   - Verify stable ForEach identity
   - Move heavy work out of body
   - Downsample images before rendering
   - Profile if code review is insufficient

**Output:** Clean, performant codebase

---

### Phase 6: Testing (10 min)

**Skills:** `/xcuitest`

**Steps:**

1. Setup `@MainActor` test class (Swift 6)
2. Create Page Object Model for each screen
3. Write critical path tests
4. Add `waitForExistence` (never `sleep`)
5. Handle permission dialogs
6. Screenshot on failure

For Flutter: Use `flutter_test` + `integration_test` with similar patterns.

**Output:** UI test suite covering critical paths

---

### Phase 7: Publish

**Skills:** `/apple-aso` → `/guide-macos-spm-packaging` (if macOS)

**Steps:**

1. **App Store Optimization** (`/apple-aso`)
   - Optimize title (≤30 chars, highest ranking weight)
   - Optimize subtitle (≤30 chars)
   - Keyword field (≤100 chars, no duplicates from title/subtitle)
   - Localize for target markets
   - Cross-localization bonus keywords

2. **macOS Packaging** (`/guide-macos-spm-packaging`, if applicable)
   - Build with SwiftPM
   - Package `.app` bundle
   - Sign and notarize
   - Generate Sparkle appcast

**Output:** Published or ready-to-submit app

---

### Phase 8: Documentation & Reference

**Skills:** `/apple-docs-index`

**Steps:**

1. Find and reference correct Apple documentation
2. Verify API usage against latest docs
3. Document architecture decisions

**Output:** Project documentation

---

## Time Estimates

| Phase | Duration | Can Parallelize? |
|-------|----------|-----------------|
| Vision | 30 min | No — must be first |
| Architecture | 20 min | No — depends on vision |
| Build | 2-8 hrs | Yes — screens can be parallel |
| Integration | 1-3 hrs | Yes — per framework |
| Polish | 15 min | After build |
| Testing | 10-30 min | After polish |
| Publish | 15 min | After testing |

**Total: ~4-12 hours for a complete app from zero to publish-ready**

## Common Mistakes

1. **Skipping Phase 1** — Building without product vision produces mediocre apps.
   Always run Steve Jobs critique first.
2. **Using Material widgets on iOS** — Even in Flutter, Cupertino widgets are
   mandatory for Apple-quality feel.
3. **Glass on content** — Glass is for controls/navigation ONLY. Content goes
   beneath glass, never inside it.
4. **Skipping screenshot iteration** — You cannot judge UI quality from code.
   Always screenshot and visually verify.

## Related Skills

All 28 skills in this collection:

- **Orchestration:** `/ios-dev`, `/apple-product-workflow`
- **Design:** `/ios-design-consultant`, `/ios-ui-craft`, `/ios-liquid-glass`, `/steve-jobs`
- **Guides:** `/guide-swiftui-ui-patterns`, `/guide-swiftui-animations`, `/guide-swiftui-charts`,
  `/guide-swiftui-view-refactor`, `/guide-swiftui-performance-audit`, `/guide-swiftdata`,
  `/guide-macos-spm-packaging`
- **API Refs:** `/uikit`, `/core-animation`, `/mapkit`, `/healthkit`, `/storekit`,
  `/widgetkit`, `/usernotifications`, `/eventkit`, `/appintents`
- **Cross-Platform:** `/flutter-apple-design`
- **Testing:** `/xcuitest`
- **Platform:** `/macos-design`
- **Publishing:** `/apple-aso`, `/apple-docs-index`
- **Compliance:** `/iso-13485-certification`
