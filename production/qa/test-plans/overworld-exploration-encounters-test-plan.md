# Test Plan: Overworld Exploration & Encounters

> **System**: Overworld Exploration & Encounters (`design/gdd/overworld-exploration-encounters.md`, revision 4, Approved)
> **Created**: 2026-10-23. The GDD's Acceptance Criteria name this plan as the owner of fixtures, tolerances, capture poses, walk-in captures, survey wording and the benchmark procedure. The ACs state observable outcomes; the procedures below say how each is measured.
> **Mechanism under test**: `docs/architecture/adr-0012-overworld-exploration-encounters.md` (Accepted), with ADR-0002 (Game State) and ADR-0005 §13–§14 (capture tool, overworld presentation, capture-ID tags). ADR-0012's Validation Criteria are covered by the suites below.
> **Gate**: this plan must exist before any [L] story in this system passes `/story-readiness` (GDD, "Test plan").
> **Status**: Draft. Three tools the GDD lists as "Tooling owed" do not exist yet (OW-T01–OW-T03). Each is its own story. **An AC that depends on owed tooling reports NOT ASSESSED until that tool ships, never a pass**, and a story that ships the measured feature can't close on that clause until then.

## Procedure index

| ID | Procedure | Kind | Used by |
|---|---|---|---|
| O-01 | Headless harness | [L]/[I] setup | every [L]/[I] AC |
| O-02 | Test conventions, timing and tolerances | rules | every [L]/[I]/[D] AC |
| O-03 | Fixture walk grids and configs | [L]/[D] setup | every [L]/[D] AC |
| O-04 | Data-validation suite (`validate_maps.gd`) | [D] | every [D] AC |
| O-05 | Integration rig | [I] | AC-14, 21, 23d, 27d, 33a–c, 34, 36 |
| O-06 | Named capture poses | [C]/[VF]/[UI] | AC-26b, 27, 27c, 44a, 44b, 51b, 52, 54, 45, 50b |
| O-07 | Walk-in capture procedure | [VF] | AC-30i, AC-32, AC-45e |
| O-08 | Overworld benchmark | [P] | AC-46 |
| O-09 | Paris playtest and survey | [PT]/[N] | AC-47, AC-48, AC-50b |
| O-10 | Sign-off and screenshot records | [VF]/[UI]/[N] | AC-26b, 27c, 30i, 32, 45, 45e, 50b, 51, 51b, 52 |
| OW-T01..T04 | Tooling stories | tools | AC-30i, 32, 44a, 44b, 45e, 46, 54 (T04 proposed: 47, 48, 50b) |

## O-01 Headless harness

All [L] tests drive the system through its request API (`OverworldMode`, `GroundMover.step`, `SymbolBrain.step`, `WalkGrid`, `WorldState`), never through real time, real input or the scene tree where a pure class suffices. Neighbours are stubs, as the GDD's Test harness requires:
- **Game State:** a stub that accepts or rejects `start_encounter` / map-change / `request_in_mode_fade` requests per frame (scriptable), records `register_camp(camp_id)`, and emits `on_thawed` and `transition_finished` **as separate, separately-timed calls**, so grace, removal and Dialogue order can be asserted between them.
- **Battle outcome:** a stub returning `VICTORY`, `FLED`, `DEFEAT` (with Retreat) per script.
- **Mode clock:** an injectable clock supplying `ow_dt = min(delta, dt_max)`; tests call `advance(dt)` with chosen steps, including hitches above `dt_max` (AC-40, AC-59).
- **Input:** a synthetic source for `move` (any vector, including un-normalised magnitudes such as 1.4), and `confirm`, `cancel`, `menu` with per-frame pressed / held / released, plus pointer events (AC-7b).
- **Roster:** a stub party of 1–4 with a scriptable recruit (AC-5b, AC-6).
- **Spies:** pathfinder spy (every `AStarGrid2D` query through `QueryBudget`, with frame number and kind: notice or repath), audio event spy, logger spy (warnings and errors counted and matched by ID), save-writer spy, flag spy (every flag write with its caller), world-state write spy, Codex stub (rumours added), checkpoint/`set_blocked` spy.
- **Viewport:** an injectable size, for AC-39 and AC-55.
- **RNG:** `OverworldMode`'s `RandomNumberGenerator` is injected with a fixed `seed` and `state`. MVP makes no random rolls (`zone_rate = 0`); AC-8c's spy proves none happen.

## O-02 Test conventions, timing and tolerances

- **Expected values** come from `OverworldConfig` and the records through the GDD's Formulas, never from literals. Each formula test (`symbol_speeds`, `follower_trail`, `occupation_stage`, `marker_activation`, `frame_step_safety`, `chase_visibility`, `symbol_density`, `chapter_walk_budget`) also runs once with the non-default config of O-03.
- **Timing rule (GDD).** A timed transition at `T` is asserted at `T − dt` (before) and `T + dt` (after), with `T` measured from the event the AC names (for example `transition_finished`, not `on_thawed`). Each timed test begins with a **setup guard**: `frac(T / dt)` must lie in [0.1, 0.9], or the test fails as mis-configured. The default step is 1/60 s; a test whose `T` lands on a frame uses 1/61 s, and the guard proves the choice.
- **Frame numbering:** frame 0 is the frame the event happens on, elapsed time 0. "Every frame" means every frame of the scripted run, at 1/60 s **and** at `dt_max` where the AC names both (AC-4).
- **Tolerances:**
  - ground positions and distances: 1e-4 m (AC-1a); frame-rate independence (60 × 1/60 s vs 30 × 1/30 s): 1 mm (ADR-0012);
  - trail positions: ± `trail_sample_m` / 2 (AC-4, stated);
  - facings and angles: 1e-4 rad; facing is compared as the snapped displayed facing (an enum), exactly;
  - times: one `dt` either side, by the Timing rule; contact-time bounds as stated (AC-10d: `+ 2·dt`);
  - counts (queries, repaths, warnings, audio events, rumours): exact;
  - boundary tests (AC-56: ± 0.01 m; AC-40: `|b|² < 1e-8`) use the stated numbers as literals, since the number is the point.
- **Paths (GDD).** `AStarGrid2D` is configured as ADR-0012 pins it (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, jumping off, fixed heuristic, `allow_partial_path = false`). Path tests assert length (± 1e-4 m) and properties (every cell symbol-legal, starts on a legal cell, ends at the target), **never exact cell lists**.
- **Determinism:** no wall-clock reads, no unseeded RNG, no dependence on test order. Each test builds and frees its own grid, config and stubs.
- **Naming:** `overworld_[feature]_test.gd`, functions `test_[scenario]_[expected]` (`.claude/rules/test-standards.md`).
- **Runner:** `commands.test` from `project.yaml` (gdUnit4 headless with `--remote-debug tcp://127.0.0.1:0`); never a runner line from memory.

## O-03 Fixture walk grids and configs

Fixtures live in `tests/unit/overworld/fixtures/` and are built by factory functions (`OverworldFixtures`), never inline numbers.
- **ASCII grids.** `grid_from_ascii(rows, cell_m)` builds a `TileMapLayer` and bakes a `WalkGrid` from it. Legend: `.` walkable, `#` wall, `E` EntryPoint, `X` MapExit rectangle, `C` CampSpot, `R` return marker, `B` runtime blocker, `P` patrol vertex, `L` leader start. Safe sources are passed to `WalkGrid.bake` from the legend, so `SAFE` tags come from the real bake.
- **TileSet-source-first gotcha (ADR-0012, probed on 4.7.2).** A fixture that builds a `TileSet` in code **adds the atlas source to the `TileSet` before setting any custom data** on its tiles. Setting custom data first silently loses it, and the grid bakes as all-unwalkable. The factory does this in one place, and a self-test (`test_fixture_grid_bakes_walkable_cells`) asserts the expected walkable count of a known grid, so a broken factory fails loudly instead of passing vacuously.
- **Named grids** (one file each): `open_ground` (AC-40b), `wall_slide_corner` (AC-2), `corner_90` (AC-4), `fence_detour` (AC-9d, 9k, 9h), `switchback` (AC-10b), `u_corridor` (AC-40c), `safe_edge` (AC-10e, 11), `two_components` (AC-9h), `exit_rect` (AC-15, 30g), `safe_bake_boundary` (AC-56), `blocker_round` (AC-55), `checkpoint_redirect` (AC-28b), `p1_p6_markers` (AC-24, plus a shuffled-order copy).
- **Configs.** `default_config()` is the shipped `OverworldConfig`. `alt_config()` changes every knob, still passes `validate()` (I1–I18), and is used for the second run of each formula test. `invariant_fixture(id)` returns, for each of I1–I13 and I15–I18, a config that breaks only that invariant (AC-38 lists the values).
- **Records.** Fixture `map_`, `enc_`, `ostage_`, `faction_` and ChapterFlow records in `tests/unit/overworld/fixtures/records/`, loaded through a stub catalog; records contain no file paths (ADR-0012).

## O-04 Data-validation suite

`tests/unit/overworld/data/` runs `validate_maps.gd` and the record validators two ways:
- **Over shipped content**: every shipped `map_` / `enc_` / `ostage_` record, map scene and ChapterFlow step, as at boot and in CI. **Denominator guard:** each suite first asserts the expected population (the Paris maps Town, overworld segment, dungeon and boss chamber, and at least one record of each type). An empty population **fails**; a [D] check over zero records is not a pass. Until Paris content exists, the shipped-content half of a [D] AC reports **NOT ASSESSED — no shipped records**.
- **Over failing fixtures**: one fixture per check, which must fail and name the record, marker, cell or node (ADR-0012 Validation Criteria list: a physics node of each AC-30e class, a GridMap with the default `collision_layer`, a `TileMapLayer` with collision on, a CSG node, a duplicate marker, an unknown `enc_`, a missing map scene, an EntryPoint inside an exit rectangle, a patrol on a stage blocker, a raise triggered by a Victory). The failing fixture proves the check can fail.
- "Reachable stages" are derived from the ChapterFlow step list, never hand-listed (AC-23b: the segment's set is exactly {2}).

## O-05 Integration rig

[I] tests run the real `GameStateMachine` (ADR-0002, including the in-mode fade and `register_camp` amendments), the real `OverworldMode` and `WorldState`, the real content catalog over fixture records, and a stub Battle mode that returns a scripted outcome after one frame. The mode clock is injected; the save writer writes to an in-memory store. Spies as O-01.

## O-06 Named capture poses

All [C] captures run on the presentation capture tool (ADR-0005 §13; presentation test plan P-09) at **1920×1080** unless a Deck size is named, with mode time fixed, followers 3, and the shipped follow camera framed on the leader. A **pose** is (map, stage or `LIB`, leader marker and facing, forced cue states). Cue states are forced through debug setters, not played into.

| Pose | Map / stage | Leader | Forced cues |
|---|---|---|---|
| CP-TOWN-S1 | Town, stage 1 | EntryPoint from the segment, facing in | camp sign, safe paving, exit with beacon, interact prompt on the nearest NPC |
| CP-SEG-S2 | Overworld segment, stage 2 | 2 m outside the first patrol's `symbol_chase_m`, facing it | symbol in Noticing (slip), a second in Chasing (`!` tag), a third Stunned; decree gag; checkpoint closed; exit beacon |
| CP-SEG-S2-OPEN | as above | same | the same checkpoint open |
| CP-DUN-S3 | Dungeon, stage 3 (interior profile) | pre-dungeon CampSpot's safe-zone edge | camp sign, safe paving, Permit Counter and ticket dispenser, checkpoint closed and open (two captures), beacon |
| CP-SEG-LIB, CP-TOWN-LIB | segment and Town, `region_liberation_flag` set | as their stage pose | liberated set; exit tape on the segment |
| CP-*-DECK | any pose above | same | rendered at **1280×800**, text scale 1.0 and 1.5 |

- **AC-44a / 44b:** every pose at every reachable stage, at 1080p. Each listed cue's mask (capture-ID tag, OW-T02) is converted to grayscale relative luminance (WCAG, linear sRGB); its ring is a 4 px dilation of the mask minus the mask. Pass: contrast of mean mask luminance vs mean ring luminance ≥ 3.0 per cue per pose. A cue absent from a pose where it was forced fails the pose.
- **AC-27:** CP-TOWN-S1, CP-SEG-S2, CP-DUN-S3 with the standard ID pass; measures as the AC states. `actor_contrast_min` is read as the minimum valid-sector `C_s` over all actors by presentation plan P-10 (see Findings).
- **AC-54:** every **exterior** pose (CP-TOWN-S1, CP-SEG-S2); `SKY` mask's top 25 % of rows of its bounding box, mean CIELAB L\* (sRGB, D65) ≥ 60. The liberated poses are measured and logged, not gated.
- **Logs** go to `production/qa/evidence/captures/` with the capture tool's settings record and the build hash.

## O-07 Walk-in capture procedure

Used by AC-30i, AC-32 and AC-45e. The level-review tool (OW-T03) lists the placements; the capture tool (P-09 + OW-T02) renders them at 1920×1080.
1. **List.** For each shipped map at each reachable stage:
   - AC-32: for each active symbol, its approaches: walk-grid entries into its `see_m` disc, deduplicated by 45° sector;
   - AC-45e: for each leg, its junction nodes (AC-45f defines them);
   - AC-30i: the one point where the walk-grid path from the pre-dungeon CampSpot to the Permit Counter crosses the safe-zone edge.
2. **Place.** AC-32: the symbol is frozen at its patrol point nearest the approach, the leader at `see_m + 0.1 m` from it on the approach line, facing it. AC-45e: the leader at the junction node, facing along the leg. AC-30i: the leader at the edge point, facing the Counter. Followers snap behind; camera settles (follow camera run to rest).
3. **Measure.** Render the ID pass twice: normally, and with set geometry hidden. Visible fraction = target mask pixels in the normal pass ÷ target mask pixels in the unoccluded pass. Target: the `symbol` tag (AC-32, and the Counter for AC-30i); the next beacon in the chain (AC-45e). A target whose unoccluded mask is empty (off screen) has visible fraction 0.
4. **Pass.** Visible fraction ≥ 0.5 (AC-32, AC-45e as stated). **AC-30i** uses the same ≥ 0.5 threshold: the GDD says only "on screen", so this plan sets the tolerance (see Findings).
5. **Retain.** Every placement's screenshot, ID passes and measurement row in `production/qa/evidence/captures/walkin-[map]-[stage]/`, listed on the art-director sheet (O-10).

## O-08 Overworld benchmark (AC-46)

- **Devices:** the named GTX 1080-class PC (`project.yaml` `platform.min_spec`; machine, driver and OS recorded in the log) at 1920×1080, and a Steam Deck (native Linux export) at 1280×800.
- **Build:** a windowed **release export** (not the editor, not headless), vsync off, pipelines pre-warmed by Boot warm-up (ADR-0005 §11).
- **Map and setup (OW-T01):** `perf_overworld` at stage 3, exterior, with N symbols equal to the shipped dungeon's `N_max` at stage 3 (computed from its record by `symbol_density`; no shipped dungeon record → **NOT ASSESSED**). 3 followers, the stage's full civilian count, tilt-shift on. Debug flags `no_contact` and `no_giveup` on.
- **Case A (chase):** every symbol Chasing a leader on a scripted loop. **Valid only if** every symbol is Chasing on every measured frame.
- **Case B (fenced patrol):** every symbol Patrolling with the leader inside its radius, same component, behind a long detour; the test hook moves the leader between two adjacent cells every frame, or `notice_cache_off` is set. **Valid only if** notice queries equal `repath_per_frame_max` on every measured frame (the bounded search really runs).
- **Run:** 10 s warm-up, then 120 s measured, per case per device. **3 runs** each (plan choice; every run must pass).
- **Per frame:** frame time (larger of CPU and GPU, as presentation plan P-14), and `overworld_ms`: the duration of `step_symbols()` (symbol stepping, notice queries and repaths) in microseconds from `Time.get_ticks_usec()`, written per frame by the OW-T01 hook; the same value is exposed live as a `Performance` custom monitor.
- **Gates:** p99 frame time ≤ `frame_time_p99_ms` (16.6), worst frame ≤ `frame_time_worst_ms` (33), p99 `overworld_ms` ≤ `performance.per_system.overworld_ms` (2.0), on both devices, both cases. Any failing run fails.
- **Record:** CSV per run plus a summary in `production/qa/evidence/perf/overworld-[date].md`.
- **Gate level:** BLOCKING at the Vertical Slice gate; **NOT ASSESSED** until OW-T01 ships.

## O-09 Paris playtest and survey (AC-47, AC-48, AC-50b)

- **Players:** at least 5 first-time players who have not seen the game; no coaching. Session: New Game through the Paris chapter. Recorded (screen + audio, timestamped).
- **Facilitator log (AC-47):** for each symbol that came within `see_m` of the leader, *engaged* or *bypassed*, and for each engaged Clerk the payoff types it carried. The OW-T04 logger (proposed) records `see_m` entries and overworld movement time; without it the facilitator logs by eye and the report says so.
- **Comprehension check (AC-50b, BLOCKING).** Asked **before the player's first Bureaucratia battle**: the OW-T04 hook holds the first accepted Bureaucratia encounter request behind a facilitator prompt (the world frozen, the Menu-freeze path). Read verbatim, once, no follow-up hint:
  > **"Before this fight: from what you've seen so far, is there anything special about how these clerks can be hurt?"**

  Scored from the recording by the facilitator and one second reviewer, independently, against: *the answer states, in any words, that the enemy takes no damage (or ignores, does not process, injuries) until it is Approved (stamped).* Both must score it correct; a disagreement scores incorrect. A player who never reached the clue counts in the denominator as incorrect. **Pass: correct ≥ 60 % of players, with at least 5 players.** The result is entered in the narrative sign-off record with the retained Steam Deck capture of the clue at 1280×800 (CP-SEG-S2-DECK framed on the clue).
- **Post-chapter survey**, read verbatim, each answered **Yes** or **No**:
  - Q1. "Walking between places felt slow." (AC-48; information only, feeds OQ-9)
  - Q2. "There was a fight I avoided on purpose." (corroborates the bypass log; information only)
  - **Q3. "I was pulled into a fight I didn't choose."** (AC-47)
  - **Q4. "Fights felt like grind."** (AC-47)

  Q3 and Q4 wording is fixed by this plan and may not be paraphrased. Q1 and Q2 are plan additions, ADVISORY.
- **AC-47 goal (ADVISORY):** every player has ≥ 1 bypass and ≥ 1 engaged street Clerk, and at most 1 player answers Yes to Q3 **or** Q4 (read as one player across both questions; see Findings).
- **AC-48 (ADVISORY):** walk share = overworld moving time ÷ chapter time, from the recordings (or OW-T04), compared with `walk_share_max` and reported per player.
- **Report:** `production/qa/evidence/playtest-overworld-[date].md`.

## O-10 Sign-off and screenshot records

- **[VF]** (AC-26b, 27c, 30i, 32, 45e, 51b, 52): retained screenshots in `production/qa/evidence/`, listed with file hashes and the build in `production/qa/evidence/signoff-overworld.md`, with the art director's verdict per clause. AC-26b's Reduce Motion frame is captured at `liberation_duration_s / 2` of mode time after the removal starts. AC-52's chase and stun are also captured with Reduce Motion on.
- **[UI]** (AC-45): the screenshot set the AC lists, at 1080p and on the Deck (CP-*-DECK), at keyboard, one gamepad style and `pad_style` "Steam Virtual Gamepad", default and largest text size, as each bullet asks.
- **[N]** (AC-50b, AC-51): QA checks that `design/gdd/reviews/overworld-narrative-signoff.md` holds an entry per item in scope, with the ticks, co-signatures and content hashes the AC names. QA does not judge the narrative content.

## Tooling stories

| ID | Story | Delivers | Unblocks | Depends on |
|---|---|---|---|---|
| **OW-T01** | Overworld performance fixture | `perf_overworld` fixture map; debug flags `no_contact`, `no_giveup`, `notice_cache_off`; the leader-oscillation test hook; per-frame `step_symbols()` timer and `Performance` custom monitor; CSV logger | AC-46 | release export preset (`commands.build` unset today); Boot warm-up |
| **OW-T02** | Capture-ID tags for overworld cues | Per-cue `capture_id` node metadata and mask rendering per ADR-0005 §14: `SKY`, `notice_slip`, `chase_tag`, `stun_pose`, `checkpoint_open`, `checkpoint_closed`, `safe_paving`, `exit_beacon`, `camp_sign`, `interact_prompt`, `symbol`; the "set hidden" ID pass for O-07 | AC-44a, AC-44b, AC-54, AC-32, AC-45e (and AC-30i's measure) | presentation capture tool (presentation plan P-09, ADR-0005 Migration Step 1c) |
| **OW-T03** | Level-review walk-in tool | Lists each symbol's approaches (per stage, 45° dedup), each leg's junction nodes and the AC-30i edge point; places leader and frozen symbol; drives the capture tool; writes the O-07 rows | AC-30i, AC-32, AC-45e | OW-T02; `validate_maps.gd` junction data (AC-45f) |
| OW-T04 *(proposed, not in the GDD's list)* | Playtest logger and comprehension hold | Logs `see_m` entries, engagements and overworld moving time; holds the first Bureaucratia encounter for the AC-50b question | AC-47, AC-48 (measurability), AC-50b (timing) | — |

**NOT ASSESSED rule.** Until its tool ships, an AC that needs it reports **NOT ASSESSED — [tool ID] not shipped**: AC-46 (T01); AC-44a, 44b, 54 (T02 and P-09); AC-32, 45e, 30i (T02 and T03); AC-27 (P-09). OW-T04 is proposed: until the GDD owner adopts it, AC-47/48 run on the facilitator's log and AC-50b uses the fallback in Findings.

## Coverage

Gate levels per the GDD's Evidence tags: [L], [D], [I], [C], [VF], [UI], [N] BLOCKING; [P] BLOCKING at Vertical Slice, NOT ASSESSED until OW-T01; [PT] ADVISORY (AC-50b's comprehension item is BLOCKING through [N]). Paths below are under `tests/unit/overworld/` unless they start with `data/` (`tests/unit/overworld/data/`) or `integration/` (`tests/integration/overworld/`).

| AC | Tag | Test file(s) / evidence | Gate |
|---|---|---|---|
| 1a, 1b, 1c, 2 | L | `overworld_ground_mover_test.gd` | BLOCKING |
| 40 | L | `overworld_ground_mover_test.gd` (dt clamp, swept contact over the angle/offset fixture set, `|b|²` branch, 1-cell wall) | BLOCKING |
| 3, 7a, 7b, 7c, 7d, 7e, 7f | L | `overworld_interaction_test.gd` | BLOCKING |
| 4, 5a, 5b, 5c | L | `overworld_follower_trail_test.gd` | BLOCKING |
| 6 | L | `overworld_follower_trail_test.gd`, `overworld_world_state_test.gd` | BLOCKING |
| 8 | D | `data/overworld_map_records_test.gd` | BLOCKING |
| 8c | L | `overworld_encounter_test.gd` (zone-roll spy over `ceil(60 / dt_max)` frames) | BLOCKING |
| 8b | D | `data/overworld_map_records_test.gd` | BLOCKING |
| 9a, 9b, 9c, 9d, 9e, 9f, 9g, 9i | L | `overworld_symbol_notice_test.gd` | BLOCKING |
| 9j, 9k, 9h | L | `overworld_symbol_query_budget_test.gd` | BLOCKING |
| 10a, 10b, 10c, 10d, 10e, 11, 12 | L | `overworld_symbol_chase_test.gd` | BLOCKING |
| 40b, 40c | L | `overworld_symbol_chase_test.gd` (`open_ground`, `u_corridor`) | BLOCKING |
| 13, 15, 16, 17, 18 | L | `overworld_encounter_test.gd` | BLOCKING |
| 19a, 19b, 19c, 20a, 20b | L | `overworld_encounter_thaw_test.gd` | BLOCKING |
| 21b, 21d, 57 | L | `overworld_encounter_thaw_test.gd` | BLOCKING |
| 14, 21, 33a, 34 | I | `integration/overworld_encounter_flow_test.gd` | BLOCKING |
| 21c | D | `data/overworld_payoff_test.gd` | BLOCKING |
| 22, 23, 23c, 24, 27b | L | `overworld_stage_test.gd` | BLOCKING |
| 23b, 26c, 26e, 27e | D | `data/overworld_stage_records_test.gd` | BLOCKING |
| 23d | I | `integration/overworld_new_game_flags_test.gd` | BLOCKING |
| 25, 26a, 26d | L | `overworld_liberation_test.gd` | BLOCKING |
| 26b | VF | O-10; `production/qa/evidence/` + `signoff-overworld.md` | BLOCKING |
| 27 | C | O-06 (CP-TOWN-S1, CP-SEG-S2, CP-DUN-S3); `production/qa/evidence/captures/` | BLOCKING; NOT ASSESSED until P-09 |
| 27c | VF | O-06 stage and `LIB` poses; O-10 | BLOCKING |
| 27d, 33b, 33c | I | `integration/overworld_boss_retreat_test.gd` | BLOCKING |
| 28a, 28b, 28c, 33d | L | `overworld_checkpoint_test.gd` | BLOCKING |
| 29, 30b, 30c, 30h | D | `data/overworld_map_safety_test.gd` | BLOCKING |
| 30a, 30d, 41, 49 | D | `data/overworld_map_records_test.gd` | BLOCKING |
| 30e, 30f | D | `data/overworld_map_scene_test.gd` | BLOCKING |
| 30g | L | `overworld_map_exit_test.gd` | BLOCKING |
| 30i | VF | O-07; O-10 | BLOCKING; NOT ASSESSED until OW-T02, OW-T03 |
| 31, 31b, 31c, 31d, 42 | D | `data/overworld_bypass_test.gd` | BLOCKING |
| 32 | VF | O-07; O-10 | BLOCKING; NOT ASSESSED until OW-T02, OW-T03 |
| 35, 35b, 35c | L | `overworld_world_state_test.gd` | BLOCKING |
| 36 | I | `integration/overworld_continue_test.gd` | BLOCKING |
| 37 | L | `overworld_state_machine_test.gd` (parametrized over every row) | BLOCKING |
| 38, 39 | L | `overworld_config_validate_test.gd` | BLOCKING |
| 43 | L | `overworld_input_audit_test.gd` | BLOCKING |
| 44a, 44b | C | O-06 all poses; `production/qa/evidence/captures/` | BLOCKING; NOT ASSESSED until OW-T02 |
| 45 | UI | O-10 screenshot set | BLOCKING |
| 45e | VF | O-07; O-10 | BLOCKING; NOT ASSESSED until OW-T02, OW-T03 |
| 45f, 50 | D | `data/overworld_route_markers_test.gd` | BLOCKING |
| 45b, 45c, 45d, 58 | L | `overworld_ui_text_test.gd` | BLOCKING |
| 46 | P | O-08; `production/qa/evidence/perf/` | BLOCKING at Vertical Slice; NOT ASSESSED until OW-T01 |
| 47, 48 | PT | O-09; `production/qa/evidence/playtest-overworld-[date].md` | ADVISORY |
| 49b, 51c, 51d | L | `overworld_gag_test.gd` | BLOCKING |
| 50b | N | O-09 comprehension check + Deck capture; narrative sign-off record | BLOCKING |
| 51 | N | O-10; `design/gdd/reviews/overworld-narrative-signoff.md` | BLOCKING |
| 51b, 52 | VF | O-06 / O-10 | BLOCKING |
| 53 | L | `overworld_feedback_twins_test.gd` | BLOCKING |
| 54 | C | O-06 exterior poses, `SKY` mask | BLOCKING; NOT ASSESSED until OW-T02 |
| 56, 59 | L | `overworld_walk_grid_test.gd` (59's animation-frame clause in `overworld_clock_test.gd`) | BLOCKING |
| 55 | L | `overworld_walk_grid_test.gd` (blocker freed), `overworld_mode_misc_test.gd` (aspect warning) | BLOCKING |

ADR-0012 Validation Criteria map onto the rows above (`GroundMover`, `WalkGrid`, `SymbolBrain`, encounter, integration, CI). Its diagonal-past-a-wall-corner screenshot is retained with the first `GroundMover` story's evidence.

## Findings: criteria not testable as written, or needing an owner's ruling

1. **AC-27, `actor_contrast_min` ≥ 3.0.** The name reads like a config knob, not a measurement. This plan measures it as the minimum valid-sector `C_s` over every actor (presentation plan P-10). Needs the GDD owner's confirmation.
2. **AC-45e and ADR-0005 §14 tag list.** Only `exit_beacon` is tagged, but a leg's last beacon may sit on a story encounter, the boss or the café, which aren't exits. Those beacons have no mask, so AC-45e can't be measured for them. Proposed fix: one `beacon` tag on every chain beacon (an ADR-0005 §14 edit, technical-director).
3. **AC-30i "shows the Permit Counter on screen"** has no threshold. This plan uses the AC-32 / AC-45e rule (≥ 50 % of the mask visible). Needs confirmation.
4. **AC-47 "At most 1 player answers Yes to Q3 or Q4".** Could mean one player across both questions, or one per question. This plan uses the stricter reading (across both). Needs confirmation.
5. **AC-47 / AC-48 measurability.** Whether a symbol "comes within `see_m`", and the share of chapter time spent moving, can't be judged reliably by eye. OW-T04 (proposed) makes them measurable. Both ACs are ADVISORY, so this doesn't block them.
6. **AC-50b timing.** "Before the player's first Bureaucratia battle" needs a hold point. Without OW-T04, the fallback is to ask at the first battle's first command prompt, before any action resolves. That is a departure, and the narrative and QA owners would need to accept it. AC-48 also has no pass threshold (information only, as intended).
7. **AC-54 "every exterior stage".** The dungeon uses the interior profile, so the plan gates Town stage 1 and segment stage 2 only, and logs the liberated captures without gating them. Needs confirmation that the dungeon is out of scope.
8. **Bookkeeping.** The GDD's Tooling-owed list calls the capture-ID tags "an ADR-0005 §13 amendment"; the accepted text sits in §14 (amending the §13 tool). Also, AC-46's N needs the shipped dungeon record, so AC-46 stays NOT ASSESSED without it even after OW-T01. And `commands.build` is unset, which also blocks AC-46 (no release export preset).
9. **Plan choices beyond the GDD** (stricter, flagged for review): 3 benchmark runs per case per device, every run must pass; two-scorer agreement for AC-50b; a player who never reached the clue counts as incorrect.
