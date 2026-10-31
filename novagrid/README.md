# NovaGrid · Cosmic Puzzle

An original, ad-free MVP of a mobile block puzzle that works offline.

## Features
- 9×9 puzzle grid; clear complete rows, columns, or 3×3 boxes.
- Three-placeable-piece tray, combos, one undo per game, and high scores.
- Classic and deterministic UTC daily challenge; saved progress.
- English, French, Arabic; responsive and keyboard accessible.
- No accounts, tracking, ads, network calls, or dangerous permissions.

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

## Future
Animations, original audio design, accessibility tuning, testers, Play Store assets, publisher credentials via Workload Identity Federation, quality review, release signing and analytics opt-in.
