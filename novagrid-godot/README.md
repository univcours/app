## NEW — Candy Galaxy: physically modelled 3D candies (2026-11-07)

The visuals in BOTH **Block Puzzle** and **Blockfall**, the NEXT/HOLD panels,
the draggable tray pieces and the native Galaxy menu all use original,
physically-modelled candy pieces, **not premade pictures or a CSS imitation**.

Art architecture:

- \`scripts/Candy3D.gd\` procedurally builds **true 3D rounded candy meshes**
  and jelly spheres with toppings, sugar dots and confectionery stripes.
- \`StandardMaterial3D\`: colored jelly-like PBR **clearcoat**, low roughness,
  reflective rim and modest emission; **two actual DirectionalLight3D softbox
  lamps** and a perspective-free orthographic \`Camera3D\`.
- **One isolated \`World3D\` per candy**. This is important: using the parent
  world's shared lights caused overlapped washed-out candy colors, which was
  caught and fixed during real screenshot QA.
- \`Visuals.gd\` reuses one 128×128 \`SubViewportTexture\` for each sweet.
  The source viewports render once, while every on-board piece draws the same
  baked texture. This retains true 3D highlights while keeping gameplay
  responsive on Android. A separate legacy 2D shader fallback remains.
- Animated nebula backgrounds, real galaxy particles, glowy jelly panels and
  original multicolored sugar/sprinkle explosion particles.
- \`tests/test_candy3d.gd\` rejects versions without real meshes, 3D cameras,
  PBR clearcoat or separated 3D worlds.
- \`tests/capture_candy_gallery.gd\` renders a **real Godot showroom screenshot**
  of seven candies and checks that pink vs cyan stay visibly distinct.
- All sweets, textures, shader/material parameters and music are original; no
  Candy Crush or other copyrighted game's image/sound assets are included.

Quality controls and gameplay remain: **0 points for a placement without a
clear**, scaled multi-line combos, earnable limited tactical bombs, 7-bag and
MIT-attributed wall kicks, touch gestures, achievements and progress saves.
The candy meshes do not change the rules or block touch input.

`godot --headless --path novagrid-godot --script res://tests/test_candy3d.gd`

---

# NovaGrid: Open-Source Reborn (Godot 4.5.1)

## New professionally structured launch and gameplay foundation — 7 November 2026

This branch **`novagrid-open-source-rebuild`** is a separate, importable, native Godot game. The previous playable branch **`novagrid-godot-rebuild`** is preserved.

- `scenes/Welcome.tscn` is now the native start scene: two large animated, translucent game cards with **real procedural crystal mini-board previews**, animated nebulae, stars and orbital planets. Touch the **BLOCK PUZZLE** or **BLOCK FALL** card to enter the corresponding live game.
- `scenes/Main.tscn` remains the real gameplay scene (not embedded HTML). On pause/game-over, a **GALAXY HOME** button returns to the animated launcher.
- **Blockfall modern movement**: authentic MIT-licensed PokeTetris rotation/kick candidate source is preserved at `third_party/poketetris/Constants.gd` and adapted in `scripts/WallKicks.gd`. This adds clockwise/anticlockwise rotation, kick trials near walls/floor and a **0.42-second lock-delay grace period**. It retains fair 7-bag, Hold, ghost piece and line-only scoring.
- **Block Puzzle**: 9×9 row/column/sector clears, simultaneous multi-line combos, scarce earnable bombs. Dropping a piece without clearing a group never awards score.
- Both modes preserve existing original **Glass Galaxy shader blocks**, animated background, independent electronic sound, original layered glass-break effects, daily mission rewards, ranks, and persistent local saves.
- **Copyright:** only the MIT gameplay source tables are reused from PokeTetris, with complete license and acknowledgement in `THIRD_PARTY_NOTICES.md`. **No Pokémon visuals or audio** have been imported. See that document before distribution.

To test both the open-source rebuild and the real 2D renders:

```bash
godot --headless --path novagrid-godot --script res://tests/test_open_source.gd
godot --headless --path novagrid-godot --script res://tests/test_game.gd
godot --path novagrid-godot
```

Exporting with Godot remains independent of the existing Google Play package; use the separate debug APK for mobile QA.

---

# NovaGrid — Native Godot Rebuild (experimental)

## Visual reference fidelity — Glass Galaxy

This branch is the **native Godot 4.5.1** game, not the earlier Capacitor/Android Studio build. The approved **NovaGrid Cosmic Puzzle UI Collage** is the art direction: large illuminated Classic Puzzle/Blockfall headings, dark purple nebula and glowing planets, vivid X-faceted glass gems, sapphire neon board, dark glass Score/Best cards, pause button, and NEXT / HOLD / COMBO side rail in Blockfall.

**Classic Puzzle** now uses a **9x9** grid. Clearing complete rows, columns or 3x3 sectors earns points; placing pieces without a clear earns **zero** score. Simultaneously cleared groups earn a multi-line combo, and rare 3x3 tactical bombs unlock only after clearing many lines and passing actual score milestones.

**Blockfall** keeps a **10x18** grid, a ghost, real next-piece and touch-operated Hold (limited to one per locked piece), seven-bag tetrominoes, swipe movement, line-only scoring and distinct original audio.

**Visual QA:** capture.gd draws the actual native Godot screens, and also verifies that at least one rendered crystal is saturated rather than washed out. GitHub Actions exports the same Godot project as a side-by-side Android test APK. The original Play Store app is unchanged.

## Glass Galaxy Arcade update — 2026-11-07

The **actual Godot editor project** now uses a full animated procedural nebula backdrop, reusable glass cube shaders, translucent boards, rounded glass navigation, spinning prism shards, shockwaves and separate original glass-break/impact sound banks for Puzzle versus Blockfall.

### Touch gestures — NO bottom direction/control buttons
- **Block Puzzle**: drag a crystal from the tray into the grid, or tap a tray crystal then tap a grid cell. Positions remain grid-accurate and valid placements are previewed.
- **Blockfall**: swipe sideways to move; **tap a piece** to rotate; **swipe downward** for a hard drop; a short downward movement for controlled dropping; **press and hold the board** to accelerate the fall.
- Pause/sound/music and mode tabs remain touch-friendly glass UI at the top. Pause offers **Resume** or **New Run**, and end-of-run offers **Play Again**.
- Keyboard arrows/space remain available for desktop QA, without any screen-space arrows.

### Offline progression with no paid advantage
- Each legitimate placement/drop and line clear earns XP. Higher level unlocks rank names **Rookie → Nova Legend**.
- Daily tasks, first-time achievements and daily streaks award persistent stars exactly once. All are earned in-game, never purchased.
- Five animated galaxy palettes unlock at levels 1, 4, 9, 16, 28. Tap the **glass XP bar at the bottom** to change among unlocked themes.
- Progress is saved locally along with both modes in `user://novagrid-godot-save.json` and restored when re-opening. No online account, ad SDK or backend is required.

To test progression alone:

```bash
godot --headless --path novagrid-godot --script res://tests/test_progression.gd
```


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
