# NovaGrid – native-screen design

Implemented: the approved cosmic-logo image is embedded as `novagrid/web/logo.webp`, used in the in-game header and auto-generated Android launcher icons.
The portrait game layout uses `web/view.css`; `web/app.js` measures available height and calculates the maximum square 9×9 board that fits, without ordinary vertical page scrolling. Gameplay remains fully interactive.

The real Android battery/signal/time status bar is shown using Capacitor 8's SystemBars, with dark strip backdrop and CSS safe-area padding. We do not draw artificial status icons. Modern Android 16 enforces edge-to-edge; the CSS SystemBars inset variables avoid text being covered.

Native Banner ads use dedicated bottom height from AdMob; the board resizes when the banner loads. Only official Google test ads run in debug builds, production still requires approval/signing.

To sync on your Windows laptop: `git pull`, then `npm install` and `npm run android:sync`. This generates updated icons in the Android native project; do not edit generated mipmaps by hand.

To verify: test physical devices with 320–430dp widths, 640–900dp heights, Android 13–16; confirm no clipped game controls with system status bar and AdMob banner visible, no scroll, Arabic RTL, and accessible text scaling. The approved artwork is NOT the screenshot concept – the board and controls are real buttons, not a static image.
