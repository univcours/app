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
