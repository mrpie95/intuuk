# intuuk

A calorie and macro tracker that respects the long arc.

One bad day shouldn't break a week. A week shouldn't break a month. The body is the average, not the moment.

---

## What it is

A native iOS app for logging meals through one of three paths — manual entry, label scanning, or a curated foods grid — all surfaced in a single full-screen sheet. Built end-to-end in SwiftUI, leaning on iOS 17+ primitives (liquid glass, content transitions, sensory feedback). No third-party dependencies.

Stage 1 is logging. The current focus is making the entry surface itself effortless enough that tracking sticks past week two — most macro apps fail on the input ceremony alone.

---

## Stack

```
SwiftUI            ·  view layer
SwiftData          ·  persistence
AVFoundation       ·  camera capture
Vision             ·  on-device OCR for nutrition labels
CoreHaptics        ·  custom-curve haptic feedback
```

Apple-native everything. Builds with Xcode 16+, targets iOS 17+.

---

## Structure

```
TimeMe/
├── TimeMeApp.swift          App entry point
├── MainView.swift           Dashboard, hero balance, history
├── LogMealView.swift        The log experience (full screen)
├── FoodScannerView.swift    NutritionScanner (Vision OCR engine)
├── FoodEntry.swift          SwiftData model
├── HapticLab.swift          Reusable CoreHaptics playground
├── Components.swift         Shared SwiftUI primitives
└── SettingsView.swift       Preferences and dev tools
```

---

## Principles

**No nudges.** If commitment isn't there, a notification won't save it. That smell is desperation.

**No streaks.** A daily streak punishes real life. Aggregate over the long arc — weeks and months. See: Apple Activity rings.

**No waiting.** Tap to log. Long-press to scan. The camera is live by the time your hand is up.

**Native shape.** Lean into the platform. Liquid glass, system fonts, segmented controls, contextual haptics. Fight the platform later, only if you must.

---

## Roadmap

**Stage 1 — Logging that doesn't friction you out**  *(current)*
Three input paths in one sheet. Inline scanner with live macro readout. Smart merge for repeated foods. Servings ↔ grams toggle. Long-press shortcut from the home button straight into scan mode.

**Stage 2 — The story over time**  *(next)*
Calendar-style history (Apple Health pattern). Weekly and monthly goals — a way to "save for dessert" without guilt. Tap a past meal to re-log or edit it.

**Stage 3 — Beyond the label**
The hot-dog-on-the-street problem. Restaurant meals, home cooking, leftovers. Direction TBD.

---

## Getting started

```
git clone https://github.com/mrpie95/intuuk.git
cd intuuk
open TimeMe.xcodeproj
```

⌘R to build and run on a simulator or device.

---

## Credits

Architect — [@mrpie95](https://github.com/mrpie95)
Code partner — Claude (Anthropic)
Vision OCR — Apple Vision framework
Haptic authoring — Apple CoreHaptics
