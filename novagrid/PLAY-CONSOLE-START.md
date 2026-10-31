# Start NovaGrid publication in Google Play Console

Status: PREPARATION STARTED. No Play Console app has been created or submitted by the assistant. The GitHub connection does not grant Play Console access.

## Verified project facts

App name: NovaGrid
Android package: com.novagrid.cosmicpuzzle
Framework: Capacitor Android 8.5.3
Android target API: expected 36 from Capacitor 8, now checked explicitly by CI
Game modes: Classic, Daily Challenge, Blockfall, Stages
Campaign: seven sections / 14,000 stages
Advertising: no banner; interstitial only (Google test ads in current debug builds)
Latest known successful Android build before publication prep: run 41250039629, with debug APK and UNSIGNED AAB.

## Step 1 — create the app in Play Console

Open https://play.google.com/console
Create app (if it does not already exist), name NovaGrid, select Game, proposed Free pricing, agree to declarations after reviewing them, and complete any required developer account identity verification.
The package must be com.novagrid.cosmicpuzzle. Keep it unchanged: changing it would create a different Android app.

## Step 2 — secure release signing

The GitHub workflow novagrid-build.yml now detects four repository secrets and then produces an additionally signed AAB artifact. It does not need nor store the private key in the source repository.

Create the UPLOAD KEY in Android Studio on your computer through Build > Generate Signed Bundle / APK > Android App Bundle > Create new key store.
Back up the keystore and its passwords securely for future updates.

Create GitHub repository Actions encrypted secrets with these exact names:
NOVAGRID_UPLOAD_KEYSTORE_BASE64
NOVAGRID_UPLOAD_KEYSTORE_PASSWORD
NOVAGRID_UPLOAD_KEY_ALIAS
NOVAGRID_UPLOAD_KEY_PASSWORD

To encode your keystore file locally in Windows PowerShell (example path must be replaced):
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\MyPrivateFolder\novagrid-upload.jks"))

Paste that long Base64 text DIRECTLY into GitHub Actions secret NOVAGRID_UPLOAD_KEYSTORE_BASE64. Do NOT post it in chat, issues, logs, public files or screenshots. Never commit a JKS file or the service-account JSON.

After the secrets are set, rerun the NovaGrid Android beta workflow for the novagrid-mvp branch using the GitHub Actions interface (or the next push on that branch will trigger it). When it succeeds, download the artifact named:
novagrid-play-internal-signed-aab

If the secrets are absent, the workflow still builds only the debug APK and unsigned AAB.

## Step 3 — app content and public privacy URL

Review the draft PRIVACY.md and the in-app privacy.html.
Google Play also requires an EXTERNAL publicly accessible HTTPS page that contains the final privacy notice. The draft is not yet publicly hosted for Play verification.
Add a valid publisher support address to the final notice. Do not invent an email.
In Play Console complete accurate Privacy policy, Data safety, Ads (YES), App access, Target audience, Content rating and all other app-content declarations.

## Step 4 — Store listing

See PLAY-STORE-LISTING.md for English, French and Arabic text. App title must be NovaGrid in every locale.
Provide 512 × 512 Play icon, 1024 × 500 RGB feature graphic, and real screenshots captured on an actual device. Screenshots must reflect the current game UI and supported languages.

## Step 5 — Internal testing first

Go to Test and release > Testing > Internal testing (navigation labels may vary).
Create a release and upload novagrid-play-internal-signed.aab. Set the version, release notes and tester accounts. Configure Play App Signing at the prompts.
Review the Play pre-launch report and test upgrading from this signed build. Do not submit an unsigned AAB.

New personal developer accounts created after 13 November 2023 must satisfy Google Play closed testing: at least twelve opted-in testers continuously for fourteen days, then request production access. This does not apply uniformly to organization accounts or older personal accounts.

## Not completed

No live app creation, policy acceptance, price selection, signing-key creation, secret registration, real screenshot capture, published privacy URL, signed upload, test-track rollout or public production submission has happened yet. These require the publisher's access, secrets and judgment.
