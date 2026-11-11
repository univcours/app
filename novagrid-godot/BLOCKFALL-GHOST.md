# Blockfall transparent soft-neon landing guide

The falling piece's projected landing squares in Blockfall now use **transparent softly glowing coloured tiles without any border**. The ghost is translucent and deliberately much fainter than the actual luminous glass cubes.

- Central colour fill: **10% alpha**, in the current piece's neon hue, slightly lightened for gentle illumination.
- Full Effects mode: two filled diffuse halo layers (**1.54%** and **2.8%** alpha) extending outside the projected square. They are not outlines and contain no line drawing. Reduced Effects mode omits these two extra layers for low-end Android phones.
- No X engravings, no glowing frames, no visible borders, no opaque fill.
- Only affects the Blockfall landing ghost. Classic's HINT, actual falling/locked cubes, piece physics, save state, XP, stars, scoring, ads and controls are unchanged.

Quality gate: existing `test_blockfall_ghost.gd` now checks the translucent glow and borderless implementation; the existing 12-screen runtime capture includes a real portrait Blockfall screenshot of the landing ghost. Run all Godot regression suites on both Linux and Windows and export the two Android debug APK variants before merging. Physical-device brightness remains a manual visual QA item.
