# NovaGrid — Approved cosmic-neon app icon

The exact approved NovaGrid neon artwork replaces the legacy launcher image.

* **Godot project icon:** `res://assets/icons/NovaGrid-Godot-Icon-512.png`
* **Android legacy icon:** `res://assets/icons/NovaGrid-Android-Main-192.png`
* **Android adaptive foreground:** `res://assets/icons/NovaGrid-Android-Adaptive-Foreground-432.png`
* **Android adaptive background:** `res://assets/icons/NovaGrid-Android-Adaptive-Background-432.png`
* **Android 13+ themed monochrome:** `res://assets/icons/NovaGrid-Android-Adaptive-Monochrome-432.png`
* **Google Play store listing image:** `res://assets/icons/NovaGrid-Play-Store-512.png`

The Play listing graphic is a separate 512 × 512 pixel PNG. The adaptive launcher uses a centered, inset rendering so Samsung/Android masks do not erase the main NovaGrid wordmark. The classic icon preserves the exact approved composition. All export profiles inherit these explicit launcher settings from the Godot Android preset, including AdMob TEST and the official API 36 AAB release template.

Run `godot --headless --path novagrid-godot --script res://tests/test_branding.gd` to validate the icon resources and Android preset bindings.

The app's Android package ID, signing configuration, AdMob IDs and saved gameplay data are unchanged. Existing installed apps may briefly show an icon cache; restarting the launcher or reinstalling a test build refreshes the launcher icon.
