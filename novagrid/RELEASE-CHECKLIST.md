# NovaGrid — launch checklist (31 October 2026)

This is the current, verifiable release checklist for **NovaGrid: Cosmic Puzzle**, package `com.novagrid.cosmicpuzzle`. All live changes go to GitHub branch `novagrid-mvp`; the repository default `master` is a different application and should be left alone.

## Done and verified

- [x] Original offline 9×9 block puzzle engine and UI in `novagrid/web/`.
- [x] Classic game, daily challenge, high scores, one undo, combos, Arabic/French/English.
- [x] Ten automated unit tests pass in GitHub Actions.
- [x] Capacitor Android debug APK and **unsigned** release AAB built by GitHub Actions.
- [x] Android Studio native project exported from workflow artifacts.
- [x] Android Studio setup helper: `setup-android-studio.cmd`.
- [x] GitHub update helper: `update-from-github.cmd` (Git pull then Capacitor sync).
- [x] Google Play Developer API and service account were configured in Play Console by the owner (do not commit credentials).

## Critical next tasks — testing and app quality

- [ ] Clone `novagrid-mvp`, generate Android project, open in Android Studio, complete Gradle sync.
- [ ] Run on at least one physical Android phone and test tap placement, valid/invalid moves, undo, restart, game-over dialog, both game modes, language RTL, rotation/font scaling and resume-after-background.
- [ ] Review game experience: optional drag-and-drop controls, haptic feedback, animations, better sounds, onboarding/tutorial, progression/rewards. These are enhancement ideas, not completed features.
- [ ] Validate persistence: storage across process restarts, fresh daily seed each UTC day, behavior after low-storage data corruption, accessibility.
- [ ] Replace Capacitor default launcher and splash icons with final original NovaGrid assets.
- [ ] Add more automated tests and phone/emulator smoke tests before release.

## Critical next tasks — release & Play Console

- [ ] Create/verify a Play Console **Game / Free** app with package `com.novagrid.cosmicpuzzle`. Verify package availability before uploading.
- [ ] Verify Android target SDK is API 36 or higher for new submissions from 31 Aug 2026.
- [ ] Generate a persistent, privately backed-up upload keystore and **sign a release AAB**. Never put the keystore/password/Google service-account JSON in Git, screenshots, or chat.
- [ ] Configure Play App Signing; test installation and updating via internal testing (not just a sideloaded debug APK).
- [ ] Create and host final privacy policy URL, verify actual SDK data practices, complete Data safety and content declarations, audience, content rating, ads status, app access, etc.
- [ ] Prepare original 512×512 listing icon, 1024×500 feature graphic, valid real game screenshots, multilingual title/descriptions and developer support contact.
- [ ] Create internal testing release; review crashes/pre-launch report and tester feedback.
- [ ] For a qualifying new personal developer account, run closed testing with at least 12 continuously opted-in testers for at least 14 days, then apply for production access.
- [ ] Set up secure GitHub-to-Google federation and Play publishing permissions only after first manual review/test build (OIDC / Workload Identity preferred); automate subsequent signed releases.
- [ ] Publish only after reviewing Google Play policy checks, tester feedback and final signed artifact.

## Day-to-day development workflow

1. Clone repository and switch to `novagrid-mvp` (not default branch `master`).
2. Launch `novagrid/setup-android-studio.cmd` one time to generate the native project, or open the CI Android Studio ZIP as a read-only snapshot.
3. To receive code updates, run `novagrid/update-from-github.cmd` or manually `git pull`, `npm install`, `npm run android:sync`.
4. In Android Studio select connected device / emulator and Run.
5. To send tracked changes, commit/push on `novagrid-mvp`. `novagrid/android/` is currently Git-ignored, so native-only edits inside it are **not** kept by Git automatically.

## Reference links

- https://github.com/univcours/app/tree/novagrid-mvp/novagrid
- https://github.com/univcours/app/actions/workflows/novagrid-build.yml
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://developer.android.com/studio/publish/app-signing
