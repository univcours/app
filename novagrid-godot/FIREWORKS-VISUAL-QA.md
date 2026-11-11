# Fireworks real-frame QA — Sprint 4

A new Godot 4.5.1 432x960 native OpenGL capture checks the visual timing of Sky Fireworks and the LEGENDARY celebration.

- 08: Real single-group row clear; sky rocket is captured after ascending into the sky and bursting.
- 09: Real 2x2 move completes **four simultaneous groups** (two rows intersecting two columns); the live game triggers Legendary Fireworks and forms the saved player name NOVA CHAMP from bright individual sparks.
- 10: A later frame captures the illuminated letter fragments falling under gravity.
- The capture fails if the real clear count, celebration tier, generated name particles, expected screenshots or rendered colour checks are wrong. Previous seven screen captures remain.
- Screenshot renders are diagnostic; they are not a physical-device benchmark or proof of animation smoothness.
- No Google Play store upload or production package/ad configuration change.

## Second visual refinement

Capture 11 now records the full Legendary sky finale at age 1.26 seconds, after rockets have detonated but before the name fully settles. Fireworks detonate inside the visible upper game starfield, not behind the score bar. Shockwave rings and bigger colour-rich comet streaks are drawn with strict same mobile particle caps; all five legendary shells get a fair particle allocation. The longer final capture shows the name shards falling more noticeably.