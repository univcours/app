# AdMob for NovaGrid

**Integration status: Google DEMO ads only**. The Android SDK is integrated through `@capacitor-community/admob@8.2.0`, and Google UMP is consulted before requesting ads. The web preview has no ads. Test banners are native and game-over interstitials are limited to natural replay breaks after at least two completed games and three minutes.

Publisher: `pub-7945572016731367`.
Previously used ad unit IDs: `ca-app-pub-7945572016731367/7155720038` and `ca-app-pub-7945572016731367/5247968960`. **They are not enabled yet.** Verify which one is a Banner and which one is an Interstitial, and confirm they belong to the AdMob app corresponding to NovaGrid. Both are *ad unit IDs*; the essential AdMob *App ID* uses `~`, e.g. `ca-app-pub-...~...`, and has not been supplied.

## If reusing an older AdMob listing
AdMob → Apps → old app → App settings → edit name/store details. NovaGrid Android package is `com.novagrid.cosmicpuzzle`. Package changes may trigger a fresh readiness review or disrupt ad serving. If the old app is still live, create a separate NovaGrid app under the same AdMob account rather than repurposing it.

## Build / testing
Run `npm install && npm run build && npx cap add android && npm run android:ads` or, after Android already exists, `npm run android:sync`.
GitHub Actions and local scripts use Google's official demo App ID and demo ad units; no live ads are requested. Do not click your production advertisements when testing.

## Production enablement — NOT DONE
Only after verifying app affiliation, ad formats, privacy disclosures, and Google policies, configure private build environment variables:

```
ADMOB_ANDROID_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
ADMOB_BANNER_UNIT_ID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
ADMOB_INTERSTITIAL_UNIT_ID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
ADMOB_LIVE_ADS=true
```

The production bundle validates these values. Never commit passwords/keys or advertise using the Google demo ID in a public release.

## app-ads.txt
The supplied content is in `novagrid/app-ads.txt` as a prepared copy, **not published**. It must be served at the ROOT of the developer website domain listed on Play Store, such as `https://yourdomain.example/app-ads.txt`. File placement here alone does not authorize inventory.

## Play requirements
Update the final privacy policy URL, Data Safety details, audience declaration, "Contains ads" declaration, and AdMob UMP privacy messages before launch.
