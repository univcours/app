# NovaGrid Galaxies — 12,000 Stages

Release target: native Android. Source: `novagrid/web/`. All 12,000 stages are deterministic, procedurally configured, **not** hand-authored. No account required.

## Six sections, six gameplay rules

Each section has **20 worlds × 100 stages = 2,000** stage IDs and an independently unlocked first level.

| Section | Stage IDs | Rule |
| --- | --- | --- |
| Cosmic Explorer | 1–2,000 | Eight alternating mission objectives: score, rows, columns, boxes, combos, survival, clearing, mastery. The original 2k campaign retains historical progress and difficulty bands. |
| Meteor Storm | 2,001–4,000 | Meteor blocks occupy additional board cells every third placement. Tray shapes favor medium pieces. |
| Gravity Forge | 4,001–6,000 | Blocks settle downward after every placement, fundamentally changing future positioning. Vertical shapes are favored. |
| Prism Temple | 6,001–8,000 | 3×3 square clears add prism energy and extra score; special objectives ask for energy. Square-compatible shapes are favored. |
| Chain Reactor | 8,001–10,000 | Multiple simultaneous clears build reactor charge, earn extra score, and occasionally remove occupied cells through a clearing pulse. |
| Void Trials | 10,001–12,000 | Meteor strikes and gravity simultaneously. Every 25th stage adds a harder boss starting geometry and two-block meteor strikes. |

The game UI shows localized section names and philosophies in Arabic/French/English. Difficulty ramps inside each section with stage-specific seeds, starting board arrangements, goals, and puzzle-tray pattern choices.

## Nova Points, stars, and progression

- Stage 1 of each section is **free to start**.
- Finish a stage successfully to earn 1–3 stars and an initial Nova Points reward.
- After completing a stage, spend the earned Nova Points to open the next stage within that same section.
- Already completed stages may be replayed, but repeating a stage at the same star rank does **not** mint extra Nova Points. Improving star rank gives a small one-time incremental reward.
- All points are fictitious **in-game progression currency**, not paid currency, and are not redeemable for cash or prizes.
- The game saves progress in local device storage; clearing app data/uninstalling can remove it unless a device backup restores the app data.
- Stage completion is resolved when no playable blocks remain, **not simply on crossing a target mid-run**. Each sector uses its own goal and bonus mechanics.
- Old `nova.galaxies` saves from the 2,000-level version are migrated via `normalizeProgress`.

## Android Banner / layout rule

Google Mobile Ads draws native ads over the WebView in Capacitor. To protect the bottom actions, `ads.js` adds `html.native-ad-layout` **before** requesting the banner and reserves at least 96 CSS pixels (or actual banner reported size + 24px). The game height and the overlay map stay above this reserved bottom dock. Re-check on each phone model and when the OS navigation mode changes.

## Advertising policy

Google test banner and test interstitial IDs remain the default in GitHub Actions/debug APK. Real ads are **not** turned on. To release live ads, complete app reviews, privacy/consent and Data Safety disclosures first, then use the verified NovaGrid AdMob App ID and ad units in a private signed release build.

## Remaining live-device QA

Test small devices (320–360dp), larger devices, gesture/three-button system navigation, Arabic RTL, and AdMob banner loading. Check each section's new stage conditions, browser and native audio mutes, and resume/restart persistence. Build/test success alone does not prove the physical app UI has been fully verified.
