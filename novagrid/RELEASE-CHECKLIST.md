# NovaGrid — Google Play release checklist

App display name: NovaGrid
Package: com.novagrid.cosmicpuzzle
Branch: novagrid-mvp (do not modify the repository's unrelated master application)
Modes: Classic, Daily Challenge, Blockfall, and Stages
Seven sectors / 14,000 stages

## Verified / prepared

- [x] Android debug APK and UNSIGNED AAB build successfully in GitHub Actions, run 41250039629.
- [x] Tests pass for gameplay, progression, and swipe mechanics.
- [x] Target SDK 36 expected from Capacitor 8; new CI check of generated Android variables.gradle.
- [x] Four-mode main navigation, title NovaGrid and no native banner.
- [x] Optional signing and **manual, gated INTERNAL testing upload** step in the GitHub workflow using Actions secrets. No key has been provided, and the current AAB is unsigned.
- [x] Draft English, French and Arabic descriptions in PLAY-STORE-LISTING.md.
- [x] Draft privacy policy visible from the game at privacy.html; final public policy hosting is not yet arranged.
- [x] Detailed instructions in PLAY-CONSOLE-START.md.

## Still blocked / requires owner action

- [ ] Play Console app created or selected, and publisher legal/identity requirements completed.
- [ ] Upload keystore generated and backed up offline; four signing secrets entered in GitHub Actions.
- [ ] Complete **first manual** signed AAB upload to Google Play Console. The Android Publisher API cannot create the app or do its first upload.
- [ ] Provide authorized service-account credential as GitHub Actions encrypted secret NOVAGRID_PLAY_SERVICE_ACCOUNT_JSON.
- [ ] Build signed artifact novagrid-play-internal-signed-aab; manually trigger workflow_dispatch with publish_internal=true to upload into INTERNAL TESTING. No production upload is configured.
- [ ] Final external HTTPS privacy policy URL and publisher contact email added to Play Console and policy.
- [ ] Play icon 512x512, feature graphic 1024x500 and real screenshots captured from a device.
- [ ] App content surveys completed truthfully: Data safety, Ads YES, Content rating, Target audience, App access, etc.
- [ ] Final advertising configuration reviewed: test ad IDs only for development/internal testing; do not publish Google demo ad IDs as live production ads.
- [ ] Test on real phones and review Google Play pre-launch testing reports.
- [ ] New personal Play Console developer accounts created after 13 Nov 2023 must complete a 12-tester, 14-day continuously opted-in closed test before requesting public production access.
- [ ] Release to production only after approval, policy checks, proper signed bundle and testing.

Links:
https://github.com/univcours/app/actions/workflows/novagrid-build.yml
https://support.google.com/googleplay/android-developer/answer/11926878
https://support.google.com/googleplay/android-developer/answer/14151465
https://developer.android.com/studio/publish/app-signing
