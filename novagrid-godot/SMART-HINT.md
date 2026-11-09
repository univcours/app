# Classic Smart Hint — Sprint 1

Owner routing: **Game Designer** (fair deterministic scoring), **Godot Engineer** (pure solver and touch wiring), **Visual UX** (gold ghost preview), **Independent QA** (unit + real input tests), **Android/Performance** (existing CI APK export).

## Player experience
- Classic adds a **HINT** action next to Replay and Blast. Tap HINT to see a gold-outline ghost and automatically select the suggested tray piece. Tap the highlighted board cells to place it; tap HINT again to dismiss.
- Hints are free, local and offline. A hint does **not** place a piece, consume stars, change score, increment XP, mutate the board or touch the saved game.
- The adviser evaluates every legal position of each remaining tray piece. It ranks actual row/column/3×3-sector clears first, then projected cleared cells, follow-up placement options and next-clear potential. It never uses hidden future pieces, ads or leaderboard values.
- A full/unplayable board returns no hint; earned blasts continue to use their existing mechanic. Blockfall keeps its original five-control HUD.
- HUD widths are recalculated per mode so 6 controls fit Classic portrait screens without overlapping the native ad dock.

## Regressions
Run using **Godot 4.5.1**:

```sh
godot --headless --editor --path novagrid-godot --quit
godot --headless --path novagrid-godot --script res://tests/test_hint.gd
godot --headless --path novagrid-godot --script res://tests/test_touch.gd
godot --headless --path novagrid-godot --script res://tests/test_layout.gd
```

The existing Cosmic Edition GitHub Action now also runs on PRs against the Cosmic branch and includes the Hint test, actual Godot import, existing suites, OpenGL captures and Android TEST APK builds. No release signing, production package ID, AdMob production settings or Play publication changes are part of this sprint.

## Limitations
The hint is a local heuristic for the **current** tray, not a guarantee of best long-term play. UI device ergonomics, 60 FPS and real ad behavior still require physical Android testing. A passing simulated touch suite is not a substitute for phone QA.
