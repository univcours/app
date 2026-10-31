# NovaGrid — full-run missions (v2)

## Core rule — no auto-skip

**A mission NEVER ends when the displayed score or objective first reaches its target.**
The puzzle engine decides when the run ends: `next.over = !hasMove(board,tray)`. As long as at least one piece can be placed, play continues.
At true game-over, evaluate the stage goal and a minimum number of played moves. If both were achieved, award 1–3 stars and Nova Points. Otherwise show **Retry** for the **same stage**. The next stage is locked until success **and** payment with earned Nova Points.

A complete run includes as many moves as the board permits. The previous artificial move limit has been removed. A player cannot unlock a stage by placing only two blocks.

## Eight mission philosophies

| Type | Mission | Starting board bias |
| --- | --- | --- |
| Score Chase | Earn at least N points by the end | Scattered starter tiles |
| Row Rescue | Complete N horizontal rows | Partially filled horizontal row |
| Column Quest | Complete N vertical columns | Partially filled column |
| Square Keeper | Complete N 3×3 squares | Partially filled 3×3 region |
| Chain Reactor | Reach N consecutive clearing moves | Crossing row and column setup |
| Cosmic Survival | Place at least N pieces in the run | Sparse orbital tiles |
| Star Cleanse | Clear at least N individual cells | Partially filled row |
| Galaxy Mastery | Clear N groups AND earn N points | A partially filled center region |

Campaign contains 20 galaxy worlds × 100 stages each. Stages are generated deterministically; different seeds and world/tier changes affect the starting board and goals. These are rule-generated stages, **not 2,000 manually balanced puzzle designs**.

## QA acceptance checks

- Put down two pieces: a stage must remain playable if a piece still fits, **even if the objective progress is complete**.
- Keep playing until no shape fits; only then show a result. Achieved objective + minimum moves => win; otherwise => replay the same stage.
- On loss, verify no Nova Points/stars or next-level unlock are awarded.
- On victory, verify new stars and points are awarded once; replaying cannot farm the same reward.
- Check all eight stage categories using levels 1–8 and their setup, objective text and map icons.
- Verify progress, unlocked stages and audio settings persist after app restart.
- Keep Classic and Daily Challenge unaffected.
- Verify mobile screen stays non-scrolling during gameplay, while galaxy map itself may scroll to show its 100 stages.
- Test the full run on a physical phone; passing unit tests and CI build alone does not validate balancing, touch accuracy or the UI on every Android handset.

## Developer commands

From the `novagrid` directory:

```powershell
npm test
npm run android:sync
```

The latest GitHub Actions build produces a debug APK with Google's **test** ads, never monetized traffic. AdMob production activation still requires approval and correct privacy disclosure.
