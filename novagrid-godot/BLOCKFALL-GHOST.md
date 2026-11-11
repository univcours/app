# Blockfall borderless faint ghost — visual QA

**Player request:** the projected square/piece indicating where the falling tetromino will land must be noticeably faded and have **no visible border**.

**Scope:** only Blockfall's projected landing positions. Real falling and locked neon cubes keep their internally illuminated multicolour glass visuals. Classic placement hints are intentionally unchanged.

The dedicated Godot renderer `_blockfall_ghost` draws a single flat translucent fill with **12% alpha**, small inset, no stroke, no outline, no glint and no texture shader. Existing collision, ghost-row calculation, scoring, touch controls, saves and ads are not modified.

**QA:** the automated `test_blockfall_ghost.gd` validates no-border source and real landing projection above occupied cells, while native capture `12-blockfall-faint-borderless-ghost.png` visually records the ghost at the bottom of an empty 10×18 board with the actual piece near the top. CI includes 19 isolated Godot suites and two Android debug APK variants, and captures 12 real frames. Check contrast on a physical Android phone before store release.
