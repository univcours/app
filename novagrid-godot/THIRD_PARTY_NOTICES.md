# NovaGrid — Third Party Open Source Notices

## PokeTetris (MIT)

Source: https://github.com/jpcerrone/PokeTetris
Upstream snapshot: commit \`6377f42670c1114d017126f62ecc54322e421b48\` (master).

Copyright (c) 2023 Juan Cerrone.

The upstream \`scr/Constants.gd\` file is preserved unmodified at
\`third_party/poketetris/Constants.gd\`, next to the exact upstream MIT LICENSE.

NovaGrid's \`scripts/WallKicks.gd\` and parts of \`scripts/Falling.gd\`
adapt its documented Super Rotation System kick offsets for Godot 4.5.1,
mobile portrait layout, controlled rotation in both directions, and
0.42-second lock grace period.

Only the gameplay data and source code above were adopted. **No Pokémon
characters, Pokéball designs, branded music, sound recordings, logos,
or pixel art are used.** NovaGrid's shader visuals, electronic music, and
glass shatter sound synthesis remain original.

We include the upstream MIT notice with the adapted code and retain
attribution. Changes are not endorsed by the PokeTetris author.

## Other open-source projects evaluated (not incorporated)

- Juicee (MIT): https://github.com/Kelpekk/Juicee — advanced game feel.
- Sparrowworks/Tetris (MIT): https://github.com/Sparrowworks/Tetris —
  another Godot 4 falling-block implementation.

They have **not** been imported into this build; we are not claiming to
ship either project or third-party content from them.
