# FINGERVERSE

Android-native **3D fingerprint portal game prototype**.

## Features
- Real procedural 3D planet, orbiting floating islands, star field and atmospheric shader (OpenGL ES 2.0).
- Native Android BiometricPrompt: successful device biometric verification awakens the world and triggers a new evolution.
- Real gravity / accelerometer tilt controls. Planet and satellites react to device orientation.
- Drag/swipe to rotate the living planet.
- Collect six animated orbiting energy shards by tapping their actual 3D screen positions; HUD tracks progress.
- Preview mode for devices without enrolled biometrics (explicitly marked preview; not a security bypass).
- Completely offline, no external backend, no third-party dependencies, no biometric data stored.

## Build
- JDK 17, Android SDK API 35, Gradle 8.13, Android Gradle Plugin 8.6.1.
- Run `gradle :app:assembleDebug` (or open the folder in Android Studio).
- Debug APK: `app/build/outputs/apk/debug/app-debug.apk`.

## How to play
Tap **AWAKEN WITH FINGERPRINT** to trigger the system fingerprint/biometric verification prompt.
After successful authentication, a dynamic alien planet appears.
Tilt your phone to steer the orbital islands and change the apparent gravity field.
Tap **AWAKEN WITH FINGERPRINT** to authenticate again and generate a new palette and planetary variation.
Collect all six glowing energy shards. Use finger drag to rotate the planet; tilt your phone to influence their orbits.
Tap **TRY DEMO** to preview on phones without biometrics.

## Privacy and sensor notes
Android never exposes raw fingerprint images or fingerprint identity to the game. The OS only
reports whether authentication succeeded. We do not save or transmit biometric templates.
Sensor readings stay in memory on the device. A real Android device is required to validate the
fingerprint prompt and tilt movement; emulator builds alone cannot validate hardware behavior.

## GitHub Actions
The `.github/workflows/fingerverse-android.yml` workflow builds a debug APK on every push to the `fingerverse-prototype` branch. Open the Actions run and download the `FINGERVERSE-debug-apk` artifact after a successful build.

## Scope and limitations
This is a playable technical prototype, not a finished open-world game. The detailed sci-fi concept images are design targets, not in-game screenshots. Character AI, quests, AR creatures, multiplayer and monetization are not implemented.