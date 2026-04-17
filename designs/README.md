# Designs

Static HTML design mockups from exploration sessions.

These are reference artifacts — not part of the iOS build. Open any `.html` file directly in a browser to view.

## Conventions

- One mockup per file. Self-contained: inline CSS, no shared assets.
- Name by what's being explored, not by date. e.g. `calendar-history.html`, `weekly-goal-meter.html`, `onboarding-step-1.html`.
- If a design supersedes an earlier one, drop the old one — `git log` is the archive.
- Screenshots / reference images can live alongside (`calendar-history.png`, etc).

## Why HTML and not Figma / Sketch?

Browser-renderable, version-controllable, diffable. AI can produce and modify them in-loop. The translation from HTML mockup to SwiftUI is more direct than from a static image — layout intent survives the handoff.
