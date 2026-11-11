# NovaGrid Fun Loop — Sprint 5

**Specialists:** Game Designer (skill-based combo rules), Economy Designer (free Stars-only earned cosmetics), Godot Engineer (shader aura update), UI/UX (native Settings Store), QA (20 suites + Android builds).

## Real features
1. **Super Combo:** existing Classic and Blockfall scoring systems award additional points for genuine consecutive clears. The on-board message now says DOUBLE COMBO x2 or SUPER COMBO x3+ based on the **actual combo chain**, not the number of rows in the most recent move. Classic adds a small golden effect at x3+; no free score is granted by the visual.
2. **Daily objectives that change:** three attainable offline UTC daily missions for Classic placements, either real clears OR two-in-a-row combos, and Blockfall drops. Seven deterministic day layouts have different goals and thresholds. Each pays Stars and XP **once**. French translations appear when the player selects FR.
3. **Earnable crystal auras:** Settings now includes a fifth, 44px+ target: Crystal Aura. CLASSIC is free; AURORA can be unlocked for 35 earned Stars; PRISM costs 80 Stars. Tapping advances to the next aura, purchasing it only when sufficient Stars exist, or cycling owned auras for free. Prices are **not real money**, no in-app purchases or ads are tied to these cosmetics.
4. **Actual visual changes:** bought skins adjust pre-baked crystal shader inner illumination and smooth polished colour rim mixing in gameplay and on Home. Exactly one 80x80 shader tile is rebuilt per hue when the aura changes, not every block each frame. The just-approved **transparent, dimly glowing, borderless Blockfall landing projection is completely unchanged**.
5. **Persistence:** uses additional optional keys in existing progression save v1, with backward-compatible defaults for old saves. Star purchases are saved through existing atomic SaveStore logic.

## Boundaries
No new Galaxy stages or Boss mode in this sprint. Existing three Galaxy missions remain honest and verified. No new permissions, production ads, billing services, tracking, signing changes or Google Play publication.

## Test gate
`test_fun_loop.gd` covers changing objectives, legitimate x2 chain triggers, one-time rewards, Stars cost validation, legacy save restore, native settings hitbox, menu store and actual game shader restoration. All **20 Godot suites** run on Linux and Windows, plus the 12 real runtime screenshots and no-ads + AdMob TEST Android debug APK exports. Manual Android testing is still recommended for luminosity and perceived fun.
