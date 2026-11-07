# NovaGrid Godot AdMob integration (safe test branch)

Project: Godot 4.5.1, branch `novagrid-godot-admob-test-20261107`.

The source-controlled `AdMobRuntime.gd.txt` is a **template**, intentionally not parsed
by normal game QA without the third-party plugin installed. The Android setup
script downloads pinned Poing Studios AdMob **v5.1.0**, verifies the release ZIP
SHA-256, installs Godot 4.5.1 Android binaries, and copies the template to
`ads/AdMobRuntime.gd`. The pre-existing non-ads game remains playable.

**Ad policies:** Banner appears only after the real native AdMob view loads, at
the very bottom of the phone. The Godot game reserves the measured pixels as
a separate dock. No gameplay buttons are covered. Interstitials are only shown
when the player restarts a **completed** round, at most every two rounds and
after a minimum interval. A Privacy button opens Google UMP options. Any
unresolved/rejected required consent stops ad requests.

**TEST APP ONLY:** `com.novagrid.cosmicpuzzle.godotpreview` uses Google's official
demo Android AdMob App ID and demo Banner/Interstitial IDs. These ads earn **no
money**. It would be incorrect to claim production AdMob revenue on this package.

**Verified user's AdMob production app (NOT auto enabled in preview):**

- App ID: `ca-app-pub-7945572016731367~1688423435`
- Banner: `ca-app-pub-7945572016731367/3815893327`
- Interstitial: `ca-app-pub-7945572016731367/2422920606`
- Rewarded: `ca-app-pub-7945572016731367/1367989694`
- Rewarded Interstitial: `ca-app-pub-7945572016731367/5391382225`

To monetize, create a **separately reviewed production update** signed with the
existing Play Upload Key and `com.novagrid.cosmicpuzzle` package, replace
test IDs in the runtime with live IDs only in the production release,
set `admob/general/android/app_id` to the verified live App ID and verify
UMP/privacy, Play Data Safety, versionCode, and on-device QA. Do not ship the
preview as production, share keys, or click your own live ads.

Plugin: https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0
License: MIT (https://github.com/poingstudios/godot-admob-plugin/blob/v5.1.0/LICENSE).

The pinned ZIP is intentionally downloaded locally rather than committed to the
repository. This is a staging implementation, not yet a signed Play release.
