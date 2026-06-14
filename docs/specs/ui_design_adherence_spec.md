# UI Design Adherence & Frontend Engineering Specification

This document details how the Modbus Studio frontend implements production-quality UI component engineering, ensures accessibility compliance, and adheres to the "Liquid Control Deck" design language while avoiding common AI-generated visual patterns.

---

## 1. Deconstructing the "AI Default Aesthetic" in Cupertino

Modbus Studio utilizes native Flutter Cupertino widgets. We intentionally avoid template-driven layouts and generic visual patterns:

| AI Default Pattern | Why It Fails SCADA Criteria | Modbus Studio Implementation |
| :--- | :--- | :--- |
| **Purple/Indigo Default** | Clashes with semantic color guidelines; creates cognitive fatigue. | **Deep Obsidian Palette**: Custom graphite (`#121216`), near-black (`#0D0D10`), and deep obsidian (`#0A0A0C`) base values absorb glare in dark control rooms. |
| **Decorative Gradients** | Creates visual clutter and compromises contrast readability. | **Flat Translucent Layers**: Subtle backdrop filter blur (sigma 10.0–15.0) and semi-transparent graphite fills represent depth rather than gradients. |
| **Generic Corner Radii** | High rounded corners (e.g. `24px`) waste viewport area. | **Radii Hierarchy**: Structured scale (`sm=8px` for buttons, `md=10px` for nav, `lg=12px` for main panels) matches structural density. |
| **Equal Oversized Padding** | Destroys grid density and causes overflow on low-res screens. | **Spacing Scale**: Hard scale (`xs=4px`, `sm=8px`, `md=12px`, `lg=16px`, `xl=24px`) to preserve terminal data density. |
| **Decorative Shadows** | Competes with text contrast and slows render loops. | **Status-Mapped Glows**: Pulsing backing glows strictly represent Modbus state (Teal = Connected, Yellow = Connecting, Red = Alarm). |

---

## 2. Component Engineering & State Architecture

To keep components performant and maintainable, the codebase separates concerns:

### 2.1 State Management Hierarchy
We apply the simplest tool for each scope to avoid complex render loops:
1. **Local State**: Managed using `flutter_hooks` (e.g., `useTextEditingController`, `useAnimationController`, `useState`) colocated inside the screen widgets.
2. **Global Reactive State**: Managed using Riverpod `NotifierProvider` (e.g., `SiteNotifier` for connection folders, `ScriptingNotifier` for JS runner logs).
3. **Data Fetching/Streams**: Decoupled from rendering. Telemetry points are streamed reactively from Rust, mapped through a stream provider, and listened to directly in the presentation widgets.

### 2.2 Presentation vs. Logic Split
Widgets are kept small, focused, and composable. For example, the **Connection Hub** separates the site organization logic (`SiteNotifier`) from the list tile layout (`_ProfileListItem`).

---

## 3. WCAG Accessibility & SCADA Usability

Industrial SCADA software is safety-critical. The frontend is engineered around strict usability gates:

### 3.1 The Mono Data Rule (Vertical Alignment)
* **Rule**: Telemetry values, Modbus register addresses, IP addresses, and hex data must be typeset in **SF Mono**.
* **Rationale**: Monospaced fonts guarantee vertical column alignment, allowing operators to scan register tables rapidly for changes or anomalies.

### 3.2 Contrast Safety & Outdoor Field Mode
* **Standard Mode**: High-contrast dark mode guaranteeing at least a **4.5:1** contrast ratio.
* **Outdoor Field Mode**: Tailored for technicians working under direct sunlight. When active, all blur effects and backing glows are disabled in favor of flat high-contrast black-and-white panels.

### 3.3 Touch Targets & Safety Clamps
* All buttons and list navigation targets have a minimum height/width of **48dp** to prevent mis-clicks in vibrating or high-pressure environments.
* Inputs are validated at user interaction boundaries, with automated alerts preventing invalid register address entries.
