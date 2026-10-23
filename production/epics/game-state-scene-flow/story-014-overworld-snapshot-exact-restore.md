# Story 014: Overworld → Battle → Overworld restores every field of the Overworld snapshot (Victory and Fled)

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§3 synchronous `ResourceLoader.load()` + `instantiate()` inside SWAP, poll-based loader; §4 freeze by detach, `on_freezing`, `on_thawed` after `mode_entered`; Engine Compatibility items 1–2)
**ADR Decision Summary**: The Overworld is frozen by detaching it from `ModeHost` (never serialized). The same instance is re-added on return, so the restore is exact by construction. `on_thawed` runs after `mode_entered(OVERWORLD)`.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Detach/re-attach behaviour is not in the engine reference. Verified empirically on 4.7.2: `_ready()` fires once in total, `_enter_tree`/`_exit_tree` once per move, and `Timer`/`Tween` freeze while detached. `Tween.is_running()` stays `true` while frozen, so no freeze/thaw code or test may use it; assert with `get_total_elapsed_time()`.

**Control Manifest Rules (this layer)**:
- Required: "Overworld freeze = detach (`remove_child`), never serialize. `on_freezing()` runs first; the instance stays alive, unparented."
- Required: "Mode scripts tolerate `_exit_tree()`/`_enter_tree()` without `_ready()` running again."
- Required: "A detached Overworld is freed explicitly on Retreat, on Quit to Title and in `GameRoot._exit_tree()`. Tests must assert no orphan nodes."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-11 [L]** GIVEN an Overworld snapshot fixture, WHEN Overworld → Battle → Overworld runs with outcome Victory, THEN every field of the restored snapshot equals the fixture. Same for Fled.

---

## Implementation Notes

*Derived from ADR-0002 §3, §4:*

- **Production `SceneLoader`** (`mode_host_scene_loader.gd`): resolves paths from `TransitionConfig`, `load` + `instantiate`, `on_freezing` → `ModeHost.remove_child(overworld)`, keeps the instance unparented, frees Battle and re-adds the same instance on return, `free_frozen_overworld()`. It accepts `pre_setup` and `payload_commit` Callables, defaulting to no-ops. Mode swaps only; overlay push/pop into the real `OverlayHost` is story 030.
- Headless, with a plain `Node` as `ModeHost` in the test's tree and the machine fed a synthetic source. No `GameRoot`.
- The fixture Overworld carries the GDD rule 5 fields (party position and facing, current map, NPC/enemy states, story flags) plus a running `Timer` and a node-bound `Tween`. Assert field by field, and check the **same instance** with `is_same`.
- Assert `_ready()` ran once and `on_thawed(encounter_id, VICTORY | FLED)` ran **after** `mode_entered(OVERWORLD)` (sequence recorder).
- The detached instance is never in the tree during Battle (`is_inside_tree() == false`).
- `on_thawed` is where the Overworld applies story flags. The fixture's `on_thawed` records a copy for the test, so the comparison is made before anything may mutate.
- This file also hosts story 012's loader-level rollback case and is reused by 021's free-on-Retreat case.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: rollback (its loader-level case lands in this story's test file).
- Story 025: `ModeHost` disable for the Menu.
- Story 030: production overlay push/pop.

---

## Files

- `src/game_state/mode_host_scene_loader.gd`
- `tests/unit/game_state/game_state_overworld_freeze_test.gd`
- `tests/unit/game_state/fixtures/stub_overworld_mode.tscn`
- `tests/unit/game_state/fixtures/stub_battle_mode.tscn`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-11**: `game_state_overworld_freeze_test.gd :: test_round_trip_restores_snapshot` (parameterized VICTORY, FLED)
  - Given: a `Node` `ModeHost` in the test tree; the real `ModeHostSceneLoader`; `stub_overworld_mode.tscn` with the GDD rule-5 fields (position, facing, `map_id`, NPC/enemy states, story flags), a running `Timer` and a node-bound `Tween`; fixture = a copy of those field values; descriptor `can_flee = true` for FLED.
  - When: Overworld→Battle; await 10 frames in Battle; outcome (VICTORY + `report_results_done`, or FLED); run to IDLE.
  - Then: `is_same(mode node, original)`; every field equals the fixture (compared before `on_thawed` may mutate: `on_thawed` records a copy for the test); `Timer.time_left` and Tween elapsed unchanged across the 10 frames; `is_inside_tree()` false during Battle; `_ready` count == 1; `_enter_tree`/`_exit_tree` counts == 2/1; recorder `index(on_thawed(id, result)) > index(mode_entered(OVERWORLD))`.
  - Edge cases: the Battle node is freed after return (`is_instance_valid` false); no orphans (exit 101 fails the run).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_overworld_freeze_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md` (the QA gate reversed the draft's 012 → 014 order: 012 now depends on this story)
- Unlocks: `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`, `production/epics/game-state-scene-flow/story-015-victory-waits-for-results.md`, `production/epics/game-state-scene-flow/story-016-fled-rejected-when-not-allowed.md`, `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`, `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`
