## NEW: one double-click launcher on Windows

The downloadable **NovaGrid-Godot-Project.zip** now includes
**`Open-NovaGrid-Godot.cmd`** in the same folder as **`project.godot`**.

1. Extract the ZIP to any folder. Do not try to run the APK inside Godot.
2. Double-click **`Open-NovaGrid-Godot.cmd`**.
3. If Godot 4.5.1 Standard is already on the computer, it is detected automatically. Otherwise a file chooser asks for its EXE. Obtain Godot only from the official website.
4. Godot opens the **real native NovaGrid editor project**. Press **F5** to start the game and select the Block Puzzle or Blockfall card.
5. Your Play Store application, signing key and Android Studio project are never touched. Android SDK/ADB and APK Downloads are not needed for PC gameplay.

For PowerShell, from the extracted project folder:
```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\scripts\open-in-godot.ps1'
```
For direct game play without showing the editor, add `-Play`.

---

# OPEN NOVAGRID ON YOUR WINDOWS COMPUTER

This folder is the complete **Godot editor project**, not an Android APK.
It is made for **Godot Engine 4.5.1** (standard Windows version).

## بالدارجة المغربية

1. نزّل `NovaGrid-Godot-Project.zip` وفك الضغط على سطح المكتب.
2. نزّل Godot 4.5.1 (Standard / Windows) من موقع Godot الرسمي، وفك ضغطه وشغلو.
3. فـGodot Project Manager، اختار **Import** ثم **Browse**.
4. اختار الملف `project.godot` الموجود داخل `NovaGrid-Godot-Project`.
5. اضغط **Import & Edit** باش تشوف الملفات والمشهد والكود فالمحرّر.
6. اضغط **F5** لتشغيل اللعبة على الكمبيوتر (أو F6 من مشهد Main.tscn).
7. غادي تشوف جوج ألعاب: Block Puzzle وBlockfall. تقدر تلعب بالماوس والكيبورد.

## Main files

- `project.godot` — the ONLY project file to choose in Godot Project Manager.
- `scenes/Main.tscn` — open this scene in the Scene dock.
- `scripts/Main.gd` — native rendering, mouse/touch interactions, animation and saving.
- `scripts/Puzzle.gd` — Block Puzzle rules.
- `scripts/Falling.gd` — Blockfall rules.
- `scripts/Audio.gd` — procedural audio and music.
- `tests/test_game.gd` — native gameplay tests.
- `assets/icon.svg` — the original app icon.

## Important

This is a **preview development project**, not a Play Store production release.
It has no live native AdMob banner yet; it does not alter the installed Play Store
version and has a different debug Android package identity.

If Windows blocks opening Godot, use **More info → Run anyway** only after
confirming it came from the **official Godot website**.

You can also open this project directly after `git sparse-checkout` without downloading a ZIP.


## Direct Android device testing from Android Studio Terminal

Android Studio's normal Run button cannot directly launch this independent
Godot project because it is not an Android Studio Gradle app.

The Godot project includes a Windows PowerShell helper at:
novagrid-godot/scripts/update-build-install.ps1

Once the branch has been fetched, run the helper from Android Studio Terminal
with powershell.exe -NoProfile -ExecutionPolicy Bypass -File and that full path.

The helper automatically updates the branch (unless SkipGitPull is supplied),
configures Godot's Android SDK/Java settings, exports an actual signed debug APK,
installs it with adb over USB and launches it on your phone.

One-time prerequisites:
- Godot 4.5.1 export templates (Editor > Manage Export Templates).
- Android Studio SDK and its Java runtime or JDK 17.
- A connected Android phone with USB debugging authorized.

It reuses a local DEBUG signing key, leaves the original Play Store package
and signing key alone, and never uninstalls any phone app automatically.
An existing preview signed with a different key causes a safe stop, not data loss.
