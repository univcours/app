# NovaGrid Smooth Multicolour Neon Glass — Sprint 3

**Owner routing:** Visual/UX Artist (glass language), Godot Shader Engineer (single-pass light), Android Performance (pre-bake + reduced effects), QA (shared palette and parser/Android regression).

Approved direction: bright multicolour internally illuminated cubes in **electric cyan, hot pink, yellow, violet, green, orange and electric blue**, with **smooth glossy glass faces: absolutely no X engraving or intersecting diagonal facets**.

- Replaced the shader's diamond/crease/triangular face geometry with a clean rounded box, internally illuminated colour core, luminous bezel, and softbox glint.
- A tiny two-ring neon halo appears behind occupied cubes in full FX mode; Low Effects omits the rings. The shader itself is **baked exactly once** into an 80x80 SubViewport texture per hue for reuse across all live Classic, Blockfall, tray and Home cubes.
- The seven hues are deliberately identical between Home and the two gameplay modes. Existing piece-colour ID mapping, save schema, touch geometry, scoring, fireworks and AdMob are unchanged.
- No new paid assets, texture fetches or production publishing. Visual effects remain a design change, not a promise of measured real-device frame rates.

## Verification

Run with Godot **4.5.1**:

\`\`\`sh
godot --headless --editor --path novagrid-godot --quit
godot --headless --path novagrid-godot --script res://tests/test_neon_crystal.gd
\`\`\`

Complete QA covers gameplay, fireworks and player-name regressions, real runtime screen captures and builds two Android debug previews (no-ads, AdMob TEST). For a true quality acceptance gate, inspect the captured gameplay image and compare it against the neon design reference, then test on a physical Android phone for glow intensity, readability and frame rate. The CI cannot prove an exact match to an illustrative mockup.
