# Nutrition App — Design Brief for Claude Code

## What we're building
A minimal, fast iOS calorie and macro tracking app. The goal is speed over precision — no accounts, no setup, just open and log. The app should feel calm and non-judgmental.

---

## The core idea
Answer one question: "Where am I today?"

Users see their remaining calories the moment they open the app. Logging is 2–3 taps maximum.

---

## Two screens

### Screen 1 — Main / Dashboard

**Layout (top to bottom):**
1. "calories left" label (small, lowercase, subtle)
2. Large number showing calories remaining (e.g. 947) — this is the hero
3. "of 2,000 goal" subtitle
4. Burndown card (tappable):
   - Default: three horizontal bars for Protein / Carbs / Fat showing how much is LEFT (burns down as you eat)
   - Tap → expands to show a line/area chart: burndown curve from 2000 → current remaining, across the day
5. Three macro summary boxes in a grid: shows grams eaten so far (e.g. "63g" with label "PROTEIN" below)
6. Large "+" button (circle) to open the log screen

**Background gradient:**
- The whole screen background is a gradient that shifts based on calories eaten vs goal
- Deficit / low intake → cool blue/purple (calm, not alarming)
- Mid-day / on track → warm amber/orange (sunrise feel)
- Near goal → deep orange/coral (sunset)
- Over goal → dark red
- This is the emotional core of the app — it should feel like a living indicator

---

### Screen 2 — Log Food (sheet/modal that appears over main)

**Layout:**
1. "What did you eat?" title
2. "tap to add · long press for slider" subtitle
3. Card with three rows — Protein, Carbs, Fat:
   - Each row: label | quick-add pill buttons | current value
   - Protein pills: +10g, +25g, +50g
   - Carbs pills: +20g, +50g, +100g
   - Fat pills: +5g, +15g, +30g
   - Current value shown on the right (e.g. "25g") — fixed width, never overlaps pills
4. Preview card showing total kcal for this entry + macro breakdown
5. Big full-width "Eaten" button (white, pill shape, prominent)

**Long press behaviour:**
- Long pressing the macro card opens a slider overlay from the bottom
- Three sliders (Protein, Carbs, Fat) for fine-tuning
- "done ↓" to dismiss

---

## Key design decisions

| Decision | Choice |
|----------|--------|
| Primary font | SF Pro (system default on iOS) |
| Colour system | Single gradient, all white UI elements on top |
| UI elements | Frosted glass cards: white at ~13–15% opacity, 1px white border at ~18% opacity |
| Border radius | Cards: 20–22pt. Buttons: 99pt (full pill). Phone corners: 40pt |
| Macro colours on bars | Protein: white. Carbs: warm cream/amber. Fat: soft mint green |
| Typography | "calories left" = small caps/uppercase, 11pt. Hero number = 58–62pt, weight 400–500. Labels = 9–10pt uppercase |
| Haptics | Light impact on every pill tap. Medium impact on "Eaten" button. (UIImpactFeedbackGenerator) |
| Data persistence | SwiftData or CoreData. Log entries stored as events: { timestamp, protein, carbs, fat }. Totals calculated by summing today's entries |
| Default goals | Calories: 2000. Protein: 150g. Carbs: 250g. Fat: 65g. (User-editable in future version) |
| No account required | All data stored locally on device |

---

## Gradient colour stops (for SwiftUI LinearGradient)

```
0%   eaten → #8EB4E8 → #A78FD4  (blue/purple, deficit)
15%  eaten → #9BC4E0 → #B0A0CC
35%  eaten → #E8A878 → #F0C070  (warm amber, on track)
55%  eaten → #F09050 → #F4B040  (orange)
75%  eaten → #E87030 → #D85020  (deep orange)
90%  eaten → #CC4820 → #B83018  (coral/red)
100% eaten → #B83018 → #8C1E10  (sunset red, at goal)
115% eaten → #7A1408 → #500C04  (dark red, over goal)
```

Interpolate between stops based on `caloriesEaten / calorieGoal` ratio.

---

## Data model (suggested)

```swift
@Model
class FoodEntry {
    var timestamp: Date
    var protein: Double  // grams
    var carbs: Double    // grams
    var fat: Double      // grams
    var calories: Double { protein * 4 + carbs * 4 + fat * 9 }
}
```

Query today's entries by filtering on timestamp >= start of day.

---

## Reference
Open `nutrition_mockup.html` in a browser to see the interactive mockup.
The mockup is fully functional — you can tap the chart, add macros, hit Eaten, and use the simulator slider to see the gradient shift.
