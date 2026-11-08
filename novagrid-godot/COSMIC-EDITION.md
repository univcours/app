# NovaGrid Cosmic Edition — implementation and QA

Source audited: branch `novagrid-godot-admob-test-20261107`, remote HEAD
`b72a3bb5a91547b9003510d85424f5742d8e5a8b` on 8 November 2026.
Development branch: `novagrid-cosmic-edition-20261108`.

## Verified starting point

- Native Godot scenes: Welcome and Main. Main shares Puzzle, Falling, Progression,
  Audio and Visuals; crystal/galaxy CanvasItem shaders and original Candy3D
  procedural models are present. Optional reference images are not checked in.
- Classic really uses 9×9 rows, columns and 3×3 group clears; Blockfall uses
  10×18, a seven-bag, Hold, ghost, rotations and lock delay. Those rules remain.
- Native progression was XP/ranks/earned stars/themes/daily missions. It had no
  native Galaxy stage mode. The current web `stages.js` explicitly defines THREE
  handcrafted stages. Older 14,000-stage / seven-sector docs are stale.
- Latest original-branch AdMob CI run `42435248492` succeeded, including its actual
  APK export, demo AdMob application ID manifest check and artifact upload.
- Native Android uses `com.novagrid.cosmicpuzzle.godotpreview`. The separate web
  production app uses `com.novagrid.cosmicpuzzle`. This work preserves both;
  changing the native ID to production would require signing/save migration QA.

## Implemented

- Native responsive four-action cosmic launcher; animated procedural nebula,
  planets, original floating crystal composition, neon glass panels. There are
  no flattened menu images and no fake shop/leaderboard controls.
- One shared cached faceted crystal shader for all board/tray/menu pieces.
  Each of eight palette textures renders once. Original Candy3D remains in
  source; this edition deliberately uses crystals rather than candy sprites.
- Large square-cell boards, precise tap/drag placement, separate Next and Hold,
  distinct single/double/triple/Supernova clear headlines and strength, localized
  crystal fragments, reduced-effects setting with cheaper background shader.
- Daily: date-seeded puzzle, six cleared groups goal, resumable run/RNG state,
  once-per-UTC-date 25-star reward, isolated from Classic's board/save.
- Galaxy: three real missions ported from current web objectives. Candy-group,
  rocket-line and bomb-area mechanics, score/minimum-move goals, legitimate
  sequential unlocks, replay star improvements and saved best ratings. Native
  campaign storage is separate from web storage; no cross-engine save migration
  or obsolete 14,000-level content is claimed.
- Existing sound/music preferences preserved; native settings with effects
  quality and EN/FR menu strings. Gameplay HUD remains English.
- Android physical safe-area to logical-canvas conversion, pause/save on focus
  loss/background, reserved native ad dock excluded from board layout.
- Atomic temporary-save rename, last valid backup and quiet malformed-JSON
  recovery. Unknown top-level keys preserved. Transactional rule-state loading
  rejects impossible pieces, malformed types and corrupt boards.
- Blockfall grounded movement can reset lock delay at most 15 times per piece;
  the reset budget persists, and old saves without the new field still load.
- Debug ads cannot select live IDs even if production flags were accidentally set.
- Debug versionCode is now 4 for both preview variants (previous AdMob TEST was 3).
- Dedicated Godot 4.5.1 QA/Android workflow. Real tests, actual OpenGL screenshots,
  no-ads and native Poing AdMob TEST APKs, package/demo-ID manifest checks,
  uploaded reports/screenshots/APKs, failure on compile/script/export errors.
- Windows update/build/install helper now follows this branch, tests an isolated
  source copy, checks Godot output and preserves a local reusable debug key.

## Verification

Use Godot **4.5.1**, not the environment's preinstalled 4.6.3. CI executes ten
suites: game, progression, touch, layout, audio, back_navigation, cosmic,
integrity, open_source and menu. New integrity and cosmic tests exercise corrupt
save recovery, wall/lock behavior, stages, daily reward integrity, input boundaries,
settings, lifecycle and safe-area mapping. Menu tests use real touch handlers.

`tests/capture_cosmic.gd` captures seven real 432×960 framebuffers: main menu,
populated Classic, genuine row-clear effects through the touch handler, Daily,
active Blockfall, Galaxy map and settings. It additionally checks rendered
crystal saturation and records renderer/frame-time diagnostics in
`build/render-report.json`. Run screenshots with an OpenGL display, not the
headless dummy renderer. All testing must use isolated application data because
these suites deliberately write save fixtures.

Historical reference-image tests require their old optional PNG fixtures and are
not acceptance tests for the new native shader skin. Original Candy3D code stays
available but its old candy-atlas visual expectation does not apply to crystals.

Local verification: 10 suites passed, 0 failed; the new integrity, integration
and menu suites contain 221 + 285 + 45 = 551 passing assertions. Seven actual
OpenGL captures and all seven crystal color checks passed. Software full/low
effects frame times are retained as diagnostics, never as phone FPS claims.

Godot 4.5.1 emits five verified editor Dummy-renderer RID teardown diagnostics
when a custom SceneTree configures editor SDK paths. The helper now waits for
the filesystem scan; CI and the Windows script classify only those exact types
at that single configuration step and require its completion marker. All other
errors and all gameplay/import/export/compile errors remain fatal.

The pinned Poing AdMob 5.1.0 controller's `--check-only` run under Godot 4.5.1
also reports exactly `ERROR: 4 resources still in use at exit (run with --verbose
for details).` CI classifies that exact shutdown line only in `admob-check.log`;
plugin import, script/parser failures, all other errors and Android exports stay
strict. APK uploads run after failures too, preserving a completed no-ads build
if a later plugin/build step fails.

## Remaining release gates

- Real Galaxy S22 Ultra/midrange-device testing: touch drag origin/preview,
  soft/hard drops, near-wall rotations, Hold, pause/resume, rotation/orientation,
  cutout/gesture-navigation insets and long sessions. No connected phone was
  available to this cloud workspace.
- Software Mesa frame-time measurements are diagnostic; they do not establish
  60 FPS, device GPU performance, battery use or Android input latency.
- Test ads only. Native UMP/consent behavior, actual test-ad delivery on Android,
  final store settings, original production signing compatibility, original
  web-to-native player save migration and Play release status need verification.
- No production signing keys were added and no Google Play publication is part
  of this change. The APK is a playable debug preview, not a release-ready claim.
- The artwork is procedural and substantially closer in structure/color/material
  to the new concept, but is not a pixel-identical reproduction of its illustrated
  planets, landscapes and hero art.

## Updating an older Windows checkout

Godot may have generated untracked `.uid` files on an older branch. Git correctly
refuses to overwrite them with Cosmic Edition's tracked UIDs.
`scripts/switch-cosmic.ps1 -Root <repository>` fetches the target branch, moves
only conflicting untracked UID files into a unique sibling backup (including
ignored UID files), then switches without overwriting ignored unrelated files.
Unrelated files, tracked edits, saves and local commits are never reset. If Git
refuses the switch, missing original UID paths are restored and the backup is
retained. Close Godot before running it to prevent concurrent UID regeneration.
After a successful switch, the existing updater runs its tests/build/install.
The bootstrap can be extracted with `git show` before checkout, so an older
branch does not need the script already present. `-SkipBuild` is for isolated
Git fixture tests only.
