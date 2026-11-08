# NovaGrid Cosmic Edition — Google Play signed release

## Official build

- Branch: `novagrid-cosmic-edition-20261108`
- Android application ID: `com.novagrid.cosmicpuzzle` (NOT the `.godotpreview` TEST ID)
- Build: **Android App Bundle (.aab)** using Godot 4.5.1 / Gradle
- Target SDK: **Android API 36**
- Release track: **manual Internal Testing first**; no automatic Google Play publication
- Live AdMob IDs are configured from the existing original production configuration. Verify the app and AdMob account ownership before public release.

## Mandatory private signing key setup

Open GitHub repository **univcours/app > Settings > Secrets and variables > Actions**.
Use the upload key already registered for this application in Play Console.

Create or update exactly these four repository secrets:

1. `NOVAGRID_UPLOAD_KEYSTORE_BASE64`: Base64 of the original *.jks / *.keystore file
2. `NOVAGRID_UPLOAD_KEYSTORE_PASSWORD`: original keystore password
3. `NOVAGRID_UPLOAD_KEY_ALIAS`: original private-key alias
4. `NOVAGRID_UPLOAD_KEY_PASSWORD`: original key password

To encode the existing keystore **locally** on Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\your-existing-upload-key.jks')) | Set-Clipboard
```

Paste the clipboard contents **only** into the encrypted GitHub secret. Keep an encrypted offline backup of the keystore and clear your clipboard afterward. Never paste the key, passwords, or service-account JSON in a public issue, repository commit or chat.

If the app **has never had an upload key**, create one privately on your own machine, keep an encrypted recovery copy, then configure these same secrets. If the app **already exists** in Google Play, use its registered upload key; do not create a different key unless you follow Google's upload-key reset procedure.

## Building

Go to **Actions > NovaGrid Cosmic — Google Play Release AAB > Run workflow**.
Choose branch `novagrid-cosmic-edition-20261108`.

The release workflow validates gameplay, generates real runtime screenshots, installs the checked Poing AdMob plugin, exports an API 36 AAB with the official Android package ID, verifies its manifest using bundletool, then **only when all four signing secrets exist** signs with `jarsigner` and checks the resulting signature.

Download the artifact **novagrid-cosmic-play-SIGNED-aab**. If this artifact is absent, there is **no signed release**. The artifact **novagrid-cosmic-UNSIGNED-not-for-play** is not uploadable for publication.

The workflow prints the upload signing certificate's public SHA-256 fingerprint. Compare it manually with Play Console > App integrity > Upload key certificate. If the fingerprint is different, do not upload the AAB.

## Before Play submission

- Confirm the AAB versionCode is strictly above the last uploaded code in Play Console.
- Ensure App Integrity/upload certificate matches the already-registered upload key.
- Provide a publicly accessible HTTPS Privacy Policy URL and truthful Data safety, Ads and target-audience declarations.
- Verify production AdMob IDs and User Messaging Platform consent. Do not use Google's test IDs for a public build.
- Verify content rating, target audience, app icon, feature graphic and actual gameplay screenshots.
- Upload to **Internal testing** first; inspect pre-launch reports and test on real Android phones.
- Use the existing Google Play listing; do not create a second app for the same package.
- Google Play accepts or rejects the release according to its current account, policy and testing requirements.

**Security:** No release keystore is generated, committed, uploaded as an artifact, or sent to the assistant. All release signing is conditional on your encrypted GitHub Actions secrets.
