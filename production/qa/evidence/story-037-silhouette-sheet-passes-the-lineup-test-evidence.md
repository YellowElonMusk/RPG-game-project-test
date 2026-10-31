# Story 037 evidence: every character's silhouette passes the 2-of-3 lineup test

**AC-33 [VF]** (GDD `sprite-camera-presentation.md`, Visual and Animation Requirements "Silhouette test"; art bible
Principle 1; ADR-0005 §1)
**Date**: 2026-10-31 | **Build**: branch `slimed-down-fork`, Godot 4.7.2 | **Status**: sheet and machine proxy done;
**art-director lineup verdict pending** (the AC's actual pass condition is human).

## What was generated

`tools/capture/silhouette_sheet_capture.gd` (headless:
`godot --headless --path . -s res://tools/capture/silhouette_sheet_capture.gd`), exit 0. It reads every shipped set
in `data/presentation/sprite_sets/` (9), builds its `SpriteFrames` (`build_sprite_frames()`, the art as played), and
resolves each pose through rule 10's `resolve()` in the role facing: squad `back` (idle, `victory`), enemies `front`
(idle, attack: AC-33 names no enemy pose, so the attack wind-up, the art bible's reaction frame, is shown). A pose
only authored in the other facing would be shown flipped (the shader flip's effect); a `no_mirror` pose is never
flipped and is reported missing. **Shipped result: every pose authored in its role facing; nothing mirrored, nothing
missing; no shipped animation is `no_mirror`.**

- Battle height: `T` = 3 per texel (1920×1080, shipped `texel_base_lines` 360). Squad and grunts 192 px, Supervisor
  and CEO 384 px. No GPU render: story 039 measured that the screen draws each texel as exactly one `T×T` block.
- 32 px: the opaque bounds fitted so the longest side is 32 px, aspect kept, a pixel black when ≥ half its area is.

Files in `story-037-silhouette-sheet-passes-the-lineup-test/`:
- `silhouette_sheet.png`: row 1 squad at battle height, row 2 enemies at battle height, row 3 every cell at 32 px 1:1,
  row 4 the same 32 px cells ×4. Characters in set-id order (baguette thrower, florida man, karen, michelin chef |
  ceo, clerk, middle manager, security drone, supervisor), three cells each: idle f0, second pose f0, second pose f2.
- `<set_id>.png` per character (battle height row, 32 px row).
- `lineup_<set_id>.png`: the reviewers' lineup of 6 at battle height (the character and the 5 most similar idle
  silhouettes, in id order). Answer positions: `measurements.json` → `lineup_answer_key`.
- `measurements.json`: every probe's pick, IoUs and lineup.

Seen: black fills on white, every character in the expected facing; squad from behind, enemies facing camera.

## Machine proxy (not the sign-off)

`SilhouetteLineupCheck`: GDD numbers kept (3, 2, lineup of 6, 32 px). Each "reviewer" is a probe pose (idle last
frame; second pose f0 and f n/2); it picks, from a lineup of the character's idle f0 plus the 5 others whose idle f0
overlaps the probe most, the silhouette with the highest IoU (feet-aligned). A tie is a wrong pick. No threshold was
invented.

| Character | Battle height votes | 32 px votes | Weakest probe (self IoU vs closest other) |
|---|---|---|---|
| Baguette Thrower | 3/3 | 3/3 | victory f0: 0.668 vs Chef 0.558 |
| Florida Man | 3/3 | 3/3 | victory f0 @32: 0.372 vs Clerk 0.346 |
| Karen | 3/3 | 3/3 | victory f0: 0.619 vs Baguette 0.594 |
| Five-Star Chef | 3/3 | 3/3 | victory f0 @32: 0.605 vs Baguette 0.586 |
| CEO | 3/3 | **2/3** | **attack f0 @32: 0.354, picked Florida Man 0.454** |
| Clerk | **2/3** | **2/3** | **attack f0: 0.521, picked Middle Manager 0.534** (@32: 0.505 vs 0.518) |
| Middle Manager | **2/3** | **2/3** | **attack f2: 0.401, picked Security Drone 0.404** (@32: 0.401 vs 0.461) |
| Security Drone | 3/3 | 3/3 | idle-vs-attack f2: 0.531 vs Middle Manager 0.465 |
| Supervisor | 3/3 | **2/3** | **attack f2 @32: 0.452, picked Security Drone 0.554** |

Roster: PASS at both sizes. **Caveat**: on all 9 sets the idle last frame has the same silhouette as idle f0
(self IoU 1.0), so the first probe is a free vote; in effect the proxy needs 1 of the 2 second-pose probes.
The five 2/3 rows above are the ones a human lineup is most likely to trip on.

## Art-director sign-off (AC-33) — pending

Run the 2-of-3 test with 3 reviewers on `lineup_<set_id>.png` (and the 32 px row of `silhouette_sheet.png`) and
record per character below. Points for the art director:
1. Proxy method choices to accept or replace: probe poses, enemy second pose = attack, "hardest lineup" selection,
   IoU metric, 32 px fit-by-longest-side.
2. Clerk vs Middle Manager attack frames and Middle Manager attack f2 vs Security Drone are near-ties.
3. Faction shape in silhouette: the Clerk reads as a round-headed figure with stamp and file box, and the Supervisor
   as a lumpy mech, not the square/rectangle the asset list describes (story 041 tracks the boss faction shape).
4. Lineup PNGs list characters in id order; shuffle before showing reviewers if position bias matters.

| Character | Battle height (reviewers correct /3) | 32 px (/3) | Verdict |
|---|---|---|---|
| Baguette Thrower | | | |
| Florida Man | | | |
| Karen | | | |
| Five-Star Chef | | | |
| CEO | | | |
| Clerk | | | |
| Middle Manager | | | |
| Security Drone | | | |
| Supervisor | | | |

Signed: ______ (art-director) Date: ______

## Tests

- `tests/unit/presentation/silhouette_lineup_check_test.gd` (23): mask, sizes, IoU, lineup, 2-of-3, poses
  (facing, mirror, `no_mirror` never flipped), probes, sheet composition.
- `tests/integration/presentation/silhouette_sheet_test.gd` (5): shipped sets: every pose present in role facing,
  none mirrored, battle height = frame × T, proxy passes at both sizes, stable set-id order.
