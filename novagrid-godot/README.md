# NovaGrid — Native Godot Rebuild (experimental)

This is a **new native Godot 4.5.1 game** built as a sibling of the original `novagrid/` application. It is **not** a destructive migration, and it has **not** replaced the Android app already installed from Google Play.

## Two playable game modes

- **Block Puzzle**: native 10×12 board, three-piece tray, direct drag/drop and tap placement, row/column clearing, combo scoring, five-move Fever, one-step undo, and saved progress.
- **Blockfall**: native 10×18 falling blocks with a seven-piece bag, collision handling, rotation with horizontal kicks, next-piece preview, ghost position, hard/soft drops, level progression, and fair clear scoring.

Both modes use a custom CanvasItem renderer with individually drawn bevelled glass blocks, celestial sky, particles, and adaptive portrait layout. Procedural music and FX are original, generated in Godot without external licensed recordings. Screen touch, drag and keyboard control are supported.

## Run and test

Open **`novagrid-godot/project.godot`** in Godot **4.5.1** (Compatibility renderer) and press F6/F5 as appropriate. The entry scene is `scenes/Main.tscn`.

CLI:

```bash
godot --headless --editor --path novagrid-godot --quit
godot --headless --path novagrid-godot --script res://tests/test_game.gd
godot --headless --path novagrid-godot --quit-after 90
```

The GitHub Actions workflow `.github/workflows/novagrid-godot.yml` runs GDScript parser checks, native rules, a smoke test and a **separately signed Android debug APK** export. The preview APK package is **`com.novagrid.cosmicpuzzle.godotpreview`**, so it cannot overwrite **`com.novagrid.cosmicpuzzle`** from Google Play or erase player progress.

## Important: AdMob and Play production

This new engine is **not yet production-ready**. The previously working Capacitor AdMob integration does **not automatically carry over** to Godot. There is no fabricated ad slot or fake paid ad in the native build. Integrating the official Android ads SDK requires a maintained Godot Android plugin/bridge, UMP consent, adaptive banner in a separate native dock, reward handling, and verified ad unit IDs before production. The default preview has zero banner height to maximize playable screen area.

Production also needs: Play-safe signing using the original upload key, increasing Play version code, Android 16 KB page-size compatibility checks, actual Samsung/device QA, store policy checks, and migration strategy for saved data if upgrading the existing application. Do **not** replace the original Play version with this preview or publish it as `com.novagrid.cosmicpuzzle` before those tasks are complete.

## Structure

- `scripts/Puzzle.gd`: self-contained puzzle mechanics, progression, save/load.
- `scripts/Falling.gd`: self-contained falling-block mechanics, save/load.
- `scripts/Main.gd`: responsive game drawing, touch controls, animations and UI.
- `scripts/Audio.gd`: original procedural sound engine.
- `scenes/Main.tscn`: native scene entry point.
- `tests/test_game.gd`: deterministic gameplay tests.
- `export_presets.cfg`: isolated debug Android export; no production signing credentials.

This rebuild is intentionally in a new directory, leaving the last known public NovaGrid source and Play listing intact.
