# AdMob for NovaGrid

**Integration status: Google DEMO ads only. NovaGrid's own AdMob App ID, Banner and Interstitial IDs have been recorded; live serving is still disabled.** The Android SDK is integrated through `@capacitor-community/admob@8.2.0`, and Google UMP is consulted before requesting ads. The web preview has no ads. Test banners are native and game-over interstitials are limited to natural replay breaks after at least two completed games and three minutes.

Publisher: `pub-7945572016731367`.
Previously used ad unit IDs: `ca-app-pub-7945572016731367/7155720038` and `ca-app-pub-7945572016731367/5247968960`. **They are not enabled yet.** Verify which one is a Banner and which one is an Interstitial, and confirm they belong to the AdMob app corresponding to NovaGrid. The first is an **Interstitial** unit and the second a **Banner** unit, verified from the owner's AdMob screenshot. Both are *ad unit IDs* and currently belong to the old AdMob listing. The screenshot also confirms the old *App ID* `ca-app-pub-7945572016731367~8159134969`, tied to `muslim tv` and store package `com.afnn.ayoudatv` (approval status: **Requires review**). **Do not insert this old App ID into NovaGrid's AndroidManifest while the listing is tied to a different package**.

## Confirmed NovaGrid app (new, separate from muslim tv)

- AdMob App ID: `ca-app-pub-7945572016731367~1688423435`
- Android package: `com.novagrid.cosmicpuzzle`
- Banner Ad Unit ID: `ca-app-pub-7945572016731367/3815893327` (confirmed by AdMob 'Ad unit successfully created' screen)
- Interstitial Ad Unit ID: `ca-app-pub-7945572016731367/2422920606` (confirmed from the AdMob Ad units screen)
- Live ads: **OFF**. Google demo App ID and demo ad units are deliberately used in APK test builds.

## If reusing an older AdMob listing
NovaGrid has now been created as a **separate AdMob app**, and both Banner and Interstitial units are confirmed. Keep the old `muslim tv` app untouched. When NovaGrid is publicly available in Google Play, link that Play Store listing, package `com.novagrid.cosmicpuzzle`, and complete app-ads.txt verification and AdMob readiness review. If instead deliberately retiring the old `muslim tv` listing, edit its **App store details → Clear store details → select NovaGrid's public store listing**, then save and confirm. Changing the package/store can trigger fresh review and interrupt existing ad delivery. **Only do this if the original old app is no longer being monetized.**

## Build / testing
Run `npm install && npm run build && npx cap add android && npm run android:ads` or, after Android already exists, `npm run android:sync`.
GitHub Actions and local scripts use Google's official demo App ID and demo ad units; no live ads are requested. Do not click your production advertisements when testing.

## Production enablement — NOT DONE
The three app/unit IDs have now been verified. **Do not enable live ads before completing Play/AdMob review and privacy disclosures.** In the release build, set the following environment variables (IDs are not secret, but keep signing credentials and Google account keys private):

```
ADMOB_ANDROID_APP_ID=ca-app-pub-7945572016731367~1688423435
ADMOB_BANNER_UNIT_ID=ca-app-pub-7945572016731367/3815893327
ADMOB_INTERSTITIAL_UNIT_ID=ca-app-pub-7945572016731367/2422920606
ADMOB_LIVE_ADS=true
```

The production bundle validates these values. Never commit passwords/keys or advertise using the Google demo ID in a public release.

## app-ads.txt
The supplied content is in `novagrid/app-ads.txt` as a prepared copy, **not published**. It must be served at the ROOT of the developer website domain listed on Play Store, such as `https://yourdomain.example/app-ads.txt`. File placement here alone does not authorize inventory.

## Play requirements
Update the final privacy policy URL, Data Safety details, audience declaration, "Contains ads" declaration, and AdMob UMP privacy messages before launch.
