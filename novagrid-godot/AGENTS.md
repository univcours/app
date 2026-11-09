# NovaGrid Cosmic Edition — Shared AI Agent Contract

Scope: `novagrid-godot/**` within `univcours/app`; cross-cutting changes only to explicitly related NovaGrid CI and agent profiles. Do **not** refactor the separate web/Capacitor app `novagrid/**` by default.

## Baseline
- Work from branch `novagrid-cosmic-edition-20261108` or a feature branch forked from it. Never assume `master` contains the same native game.
- Engine: Godot **4.5.1**, Compatibility renderer; primary project `novagrid-godot/project.godot`. Scenes `Welcome.tscn` and `Main.tscn`.
- Implemented modes: Classic 9x9, Blockfall 10x18, Daily 6-clear challenge, 3 existing Galaxy stages. Other stage counts are **not** verified.
- Keep `com.novagrid.cosmicpuzzle.godotpreview` for native preview and `com.novagrid.cosmicpuzzle` for separately published web app. No unapproved migration, overwrite, store rollout or signing changes.
- Shared files include `Main.gd`, `Welcome.gd`, `SaveStore.gd`; only the Director coordinates overlapping ownership.
- Local saves and high scores must survive valid updates. Rewarded ads must be explicit opt-in and earned-callback-only; debug builds use test ads or no ads.

## Process
1. Inspect the actual code, current branch, recent commits, relevant tests and the latest CI result.
2. Produce a task brief: player benefit, agent owner, impacted files, dependencies, acceptance criteria and rollback impact.
3. Make smallest coherent change on a feature branch; don't edit unrelated apps or files.
4. Add regression tests and run them with **Godot 4.5.1**, including real renderer captures for visual changes. Workflow: `.github/workflows/novagrid-cosmic-edition.yml`.
5. Document what is **verified** versus not tested, particularly Android device FPS, touch, cutouts, UMP, signed release and Play Console status.
6. Independent QA reviews changes; the Director integrates only after quality gates pass. Never fabricate external execution, user approvals or Play publication.

## Ownership
- Director: scope, sequencing, integration and PR review.
- Game Designer: fairness, scoring, mission balance, progression.
- Godot Engineer: GDScript gameplay and runtime logic.
- Visual & UX Artist: original cosmic visual system, shaders and touch ergonomics.
- Audio & Accessibility: original audio, settings, comfort.
- Android & Performance: Android exports, package IDs, CI, measurable performance.
- Ads & Privacy: opt-in rewards, AdMob test integration, consent.
- Independent QA: tests, regression, independent release blocker assessment.
- Store & Growth: truthful onboarding, metadata, store material.

## Minimum handoff
Return: `Goal | Owner | Branch | Changed files | Test evidence | Visual evidence if needed | Risks | Next specialist`. No passing test result without a test actually executed.
