# NovaGrid · Cosmic Puzzle

An original 9×9 block puzzle. Core gameplay works offline; Android test builds now include Google AdMob demo ads and UMP consent.

## Features
- 9×9 puzzle grid; clear complete rows, columns, or 3×3 boxes.
- Three-placeable-piece tray, combos, one undo per game, and high scores.
- Exactly **three handcrafted Candy Arcade campaign stages**, not 14,000:
  1. 🍬 **Candy Pop** — score at least 260, clear 2 lines/boxes, survive 6 moves.
  2. 🚀 **Rocket Rush** — score at least 450, fire 2 real board-clearing rockets, survive 8 moves.
  3. 💣 **Candy Bomb Boss** — score at least 700, trigger 2 real 3×3 bombs and deplete the Boss HP, survive 10 moves.
- Stages unlock **only after genuine score + objective + minimum moves**. No coins, ads or payments can bypass the next stage's requirement.
- Original synthesized candy chimes, rocket whooshes, bomb blasts, victory sounds and responsive stage-specific music.
- Six bright glass candy colors; reduced-motion-aware CSS explosions, sparks and rocket beams, mild haptics.
- Classic and deterministic UTC Daily Challenge for replay; Blockfall remains an optional bonus Arcade mode, not another campaign stage.
- Campaign progress is saved separately under `nova.candy.progress.v1`, preserving any historical Galaxy data.
- English, French, Arabic; responsive and keyboard accessible.
- No account required; game scores stay on device. Android includes Google advertising SDK with privacy consent checks.

## Try the game
Run `python -m http.server 8000 --directory web`, then open `http://localhost:8000`.
Use the piece selector then tap the 9×9 grid.

## Test
`npm test` (no dependencies needed to run tests; requires Node 22).

## Android / Play Store
Requires Node 22, Android SDK and Java. `npm install && npm run build && npx cap add android` then `cd android && ./gradlew assembleDebug bundleRelease`.
`package.json` pins Capacitor 8, which supports Android API 36. The GitHub Actions workflow creates an unsigned release `.aab` and a debug `.apk` for verification.

**Important:** The generated release AAB is unsigned; Google Play submission needs a persistent private upload signing key, secure CI secret storage, a signed AAB, and completion of the Play Console listing, privacy/data-safety declarations, and tester requirements. Never commit an upload keystore or Google service-account private JSON. Automated publishing is intentionally NOT enabled until secure identity and release signing are configured. This is an MVP, not a published game.

## Name / copyright
NovaGrid and its logo are original concepts. Check trademark / Play Store name availability before release.

## Expansion
Ship and test these three polished stages first. Add more only after real player feedback, accessibility QA and difficulty balancing. Never publish gameplay updates straight to Google Play without internal testing.

## Monetization guardrails
AdMob interstitials only at natural replay/transition breaks after at least two completed games and at least three minutes; never during active moves, explosions or Boss fights. Debug Android builds use Google demonstration ads. A Play-signed LIVE release requires explicit `ADMOB_LIVE_ADS=true`, consent and AdMob review; no revenue is guaranteed.

## Advertising
Google demo ads are used during Android testing, not live IDs. See [ADMOB.md](ADMOB.md) for requirements before activating production advertising and the prepared app-ads.txt line.
