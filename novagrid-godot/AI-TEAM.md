# NovaGrid — Specialist AI Team

These are **real GitHub Copilot custom agent profile files** in `.github/agents/*.agent.md`. They define role-specific instructions. Creating them **does not** start nine background workers or imply that each has executed a task. An eligible user activates them in a supported Copilot IDE/cloud environment. Some cloud discovery requires merging the agent profiles into the repository's default branch.

## Team routing

| Agent profile | Primary responsibility | Files |
| --- | --- | --- |
| `novagrid-director` | Manager, planning, acceptance, integration | All NovaGrid changes |
| `novagrid-game-designer` | Gameplay balance and rewarding progression | `Puzzle.gd`, `Falling.gd`, `Campaign.gd`, `Progression.gd` |
| `novagrid-godot-engineer` | Godot coding and mobile interactions | `scripts/**`, `scenes/**` |
| `novagrid-visual-ux` | UI, crystals, shaders, original art | `assets/**`, `shaders/**`, `NeonSkin.gd` |
| `novagrid-audio-accessibility` | Sound, music, feedback, accessibility | `Audio.gd`, settings |
| `novagrid-android-performance` | Godot 4.5.1, APK/AAB preview, performance | `project.godot`, exports, CI |
| `novagrid-ads-privacy` | Rewarded ads, safe banner and privacy | `ads/**`, ad integration |
| `novagrid-qa` | Independent regression and release checks | `tests/**` and all change diffs |
| `novagrid-store-growth` | Truthful Play Store metadata and player onboarding | Documentation and verified screenshots |

## How to invoke

1. Open a checkout of `univcours/app` on the Cosmic Edition development branch (or a branch based on it) in VS Code with GitHub Copilot Chat.
2. Select the matching custom agent from the agent picker, such as **NovaGrid Director**. If it is not listed, verify that `.github/agents` files are present in the opened workspace and that your Copilot environment supports custom agents.
3. Prompt: **"Audit and improve NovaGrid. Start with a prioritized plan, send each scoped task to the matching specialist where supported, implement with tests, and let Independent QA gate the change. Do not release to Play without my approval."**
4. Have each specialist work in isolated branches/PRs, keeping Director as integration owner. Cloud profile visibility may require a merge to the repository's default branch; this development branch alone does not guarantee GitHub cloud agent discovery.

## Recommended execution sequence

Director audits → Game Designer specifies → Godot Engineer implements ↔ Visual/Audio specialists improve → Android engineer builds tests → Ads specialist reviews optional monetization → Independent QA independently reviews → Director merges → Store specialist prepares verified listing.

Independent agents may handle separate files in parallel, but all changes to `Main.gd`, `Welcome.gd`, project config, exports or release workflows must be serialized to prevent conflicts. A profile's existence is configuration, not evidence of parallel task execution.

## Verification

From repository root with Godot 4.5.1 available:

```sh
godot --headless --editor --path novagrid-godot --quit
godot --headless --path novagrid-godot --script res://tests/test_game.gd
godot --headless --path novagrid-godot --script res://tests/test_rescue.gd
godot --headless --path novagrid-godot --script res://tests/test_cosmic.gd
python3 novagrid-godot/tests/test_agent_profiles.py
```

For full Android debug preview, use the existing `.github/workflows/novagrid-cosmic-edition.yml`; it checks the project and exports APKs. Additional physical Android device testing is mandatory for release. No profile may silently swap the native preview package ID with the current Play production ID.

## Next sprint — proposals, not executed gameplay features

1. UI/touch usability: test one-handed drags, short screens, gesture-navigation insets and reduced-effects on real devices.
2. Gameplay: balance 9x9 tray choice and Blockfall lock timing from deterministic replays; preserve current genuine line scoring.
3. Real Galaxy expansion: design and implement additional distinct stages only after their rules and tests exist.
4. Stability: investigate crash logs, loading latency and Android memory use on a physical low/midrange device.
5. Store: prepare accurate, real screenshot-based EN/FR listing after gameplay and Android QA pass.
