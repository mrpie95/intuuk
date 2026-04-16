```
 ┌──────────────────────────────────────────────────────────────────────┐
 │ ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL                              │
 │ INTUUK-TEC PERSONAL NUTRITION SYSTEMS DIVISION                       │
 │ ----------------------------------------------------                 │
 │ ESTABLISHING CONNECTION ......................... [ OK ]             │
 │ AUTHENTICATING USER .............................. [ OK ]            │
 │ LOADING PIP-CHEF v0.1.ALPHA ...................... [ OK ]            │
 │                                                                      │
 │   ██╗███╗   ██╗████████╗██╗   ██╗██╗   ██╗██╗  ██╗                  │
 │   ██║████╗  ██║╚══██╔══╝██║   ██║██║   ██║██║ ██╔╝                  │
 │   ██║██╔██╗ ██║   ██║   ██║   ██║██║   ██║█████╔╝                   │
 │   ██║██║╚██╗██║   ██║   ██║   ██║██║   ██║██╔═██╗                   │
 │   ██║██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝██║  ██╗                  │
 │   ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝                  │
 │                                                                      │
 │              < CALORIE & MACRO TRACKING TERMINAL >                   │
 │                                                                      │
 │ "WAR. WAR NEVER CHANGES. BUT YOUR PROTEIN INTAKE                     │
 │  PROBABLY SHOULD."           — VAULT-TEC NUTRITIONAL ADVISORY        │
 │                                                                      │
 └──────────────────────────────────────────────────────────────────────┘
```

```
> WELCOME TO INTUUK_
>
> THIS UNIT IS DESIGNED TO ASSIST IN THE CONSUMPTION
> AND TRACKING OF FOODSTUFFS WITHIN THE WASTELAND
> (OR YOUR KITCHEN. WHICHEVER IS CLOSER.)
>
> SYSTEM STATUS .......... ALPHA (PRE-WAR)
> PLATFORM ............... iOS 17+
> CHASSIS ................ SwiftUI / SwiftData
> CAMERA MODULE .......... AVFoundation + Vision OCR
> HAPTIC ENGINE .......... CoreHaptics
> _
```

---

## STATS PANEL

```
S.P.E.C.I.A.L.

[S] SCAN       ████████░░  Live nutrition-label OCR. Inline preview.
[P] PORTIONS   ████████░░  Servings ↔ grams toggle. Smart merge.
[E] ENERGY     ███████░░░  Daily kcal balance. Weekly view planned.
[C] COMMIT     █████████░  One-tap log. Long-press → straight to scan.
[I] INTERFACE  ██████████  iOS 26 liquid glass, gradient hero, full-bleed.
[A] AUDIO      ░░░░░░░░░░  Haptics only. (Silent meals, like a librarian.)
[L] LONGEVITY  ████░░░░░░  Stage 1 of N. Roadmap below.
```

---

## OPERATIONAL FEATURES

```
[*] LOG MEAL VIEW (FULL-SCREEN)
    └── Three input paths in one panel:
        ├── MANUAL  ── macro stepper with long-press-to-zero on −
        ├── SCAN    ── live camera preview, triple-pulse haptic on lock
        └── FOODS   ── swipeable categories, merge-on-retap, badge counts

[*] HOME DASHBOARD
    ├── Hero number (kcal balance, animated content transition)
    ├── Long-press the + to skip straight into scan mode
    └── History strip below the fold

[*] HAPTIC LAB                       (dev tool, see Settings)
    ├── Sine wave with live-tracked playhead graph
    ├── Linear sweep, sustained rumble, custom transient tap
    └── Self-contained module — drops into any iOS project
```

---

## INSTALLATION INSTRUCTIONS (TERMINAL)

```
> git clone https://github.com/mrpie95/intuuk.git
> cd intuuk
> open TimeMe.xcodeproj
> ⌘R                                  # ENGAGE
```

Requires Xcode 16+ targeting iOS 17+. No package manager dependencies —
the entire stack is Apple-native (SwiftUI, SwiftData, AVFoundation,
Vision, CoreHaptics).

---

## CHASSIS DIAGRAM

```
TimeMe/
├── TimeMeApp.swift          ← entry point
├── MainView.swift           ← dashboard + hero + history
├── LogMealView.swift        ← THE log experience (full screen)
│   ├── LogFoodItem          ← item model
│   ├── LogScannerView       ← inline camera + live macro readout
│   ├── LogFoodGrid          ← swipeable category chips
│   ├── LogManualEntry       ← P/C/F steppers
│   └── MacroStepper         ← reusable macro increment row
├── FoodScannerView.swift    ← NutritionScanner (OCR engine)
│   ├── NutritionScanner     ← Vision-based label reader
│   ├── CameraPreviewView    ← UIKit AVCapture bridge
│   └── ScanBracketsShape    ← viewfinder corner brackets
├── FoodEntry.swift          ← SwiftData persistence model
├── HapticLab.swift          ← reusable CoreHaptics playground
├── Components.swift         ← shared SwiftUI primitives
└── SettingsView.swift       ← preferences + dev tools
```

---

## ROADMAP (FROM THE OVERSEER'S DESK)

```
[X] STAGE 1 ── Get the input right
    └── Receipt-mode log surface, scan, foods grid, manual entry,
        merge logic, badges, serving-size toggle

[ ] STAGE 2 ── The long-arc story
    ├── Apple Health-style calendar history
    ├── Weekly + monthly goals (one bad day ≠ failure)
    ├── Edit past meals
    └── Favorites / recently logged shortcuts

[ ] STAGE 3 ── Database expansion
    └── The "hot dog on the street" problem. TBD.
```

---

## DESIGN PRINCIPLES

```
> NO NUDGES.    If you won't commit on your own, a notification
                won't save you. That smell is desperation.

> NO STREAKS.   One bad day shouldn't break a month of work.
                Aggregate over the long arc. See: Apple Activity rings.

> NO WAITING.   Tap to log. Long-press to scan. Camera is live by
                the time your hand is up.

> NATIVE SHAPE. Liquid glass, segmented controls, system fonts,
                contextual haptics. Lean into the platform —
                fight it later if you must.
```

---

## CREDITS

```
> SYSTEM ARCHITECT ........... mrpie95
> CODE OPERATIVE ............. Claude (Anthropic)
> NUTRITION SCANNING OCR ..... Apple Vision Framework
> HAPTIC AUTHORING ........... Apple CoreHaptics
> INSPIRATION ................ Bethesda Softworks (RIP Ron Perlman's voiceover budget)
```

---

```
> TRANSMISSION ENDS_
>
>   THANK YOU FOR USING ROBCO TERMLINK
>   PRESS ANY KEY TO CONTINUE_
```
