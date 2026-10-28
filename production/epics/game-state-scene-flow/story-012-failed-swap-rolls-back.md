# Story 012: A failed swap returns to the source mode with frozen state restored and input unlocked

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Implementation Guidelines: rollback; §7: a `null` start snapshot is a swap failure); ADR-0009: Save/Load & Settings (§6: `payload_commit` returning `false` is a swap failure); ADR-0010: Turn Battle System (§3: `BattleBuildResult` errors are a swap failure)
**ADR Decision Summary**: On a failed swap the machine calls `rollback_swap()`, the loader re-attaches any detached Overworld, IN plays back into the source mode, input unlocks and an error is logged. The game is never left between modes or with input locked.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0009 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The machine cases use the stub loader. The loader-level case reuses story 014's real `ModeHostSceneLoader` and its verified detach/re-attach behaviour.

**Control Manifest Rules (this layer)**:
- Required: "A swap failure calls `rollback_swap()`, re-attaches any detached Overworld, replays IN into the source mode, unlocks input and logs an error."
- Required: "The production `SceneLoader` takes an injected `payload_commit: Callable(payload) -> bool` … `false` is a swap failure (rollback)."
- Required: "A detached Overworld is freed explicitly … Tests must assert no orphan nodes."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-10 [L]** GIVEN a swap that fails (stub loader returns an error), THEN the mode returns to the source mode with its frozen state restored, input is unlocked, and an error is logged.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and the QA gate (RC-3):*

- On `poll_swap() == FAILED`, the machine calls `rollback_swap()`, plays IN **back into the source mode**, unlocks input and logs `&"swap_failed"` with `context.cause` naming the source.
- **Rollback signal sequence** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): `transition_started(from, to)` → `mode_exited(from)` → `mode_entered(from)` → `transition_finished(from)`.
- Parametrize over the three failure sources the machine can see: loader `FAILED`; `capture_start_snapshot()` returning `null` on Overworld → Battle (the base `GameMode` returns `null`, so a Battle mode that forgets to override fails loudly); a `payload_commit` false, stubbed through the loader as `FAILED`.
- **"Frozen state restored" is observable only with the real loader.** With the stub, the machine can only assert `rollback_swap()` was called. So this story also adds a **loader-level case to story 014's `game_state_overworld_freeze_test.gd`**: real `ModeHostSceneLoader`, failure after detach → the same instance is re-attached with every field equal to the fixture.
- Validating the descriptor before any detach is preferred (story 013), so most failures never need a rollback. This story covers the post-detach failure.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: request-time descriptor validation.
- Story 034: the Battle mode's boss-count failure in `setup()` (also a rollback path).

---

## Files

- `src/game_state/game_state_machine.gd` (rollback)
- `src/game_state/mode_host_scene_loader.gd` (`rollback_swap` re-attach)
- `tests/unit/game_state/game_state_swap_rollback_test.gd`
- `tests/unit/game_state/game_state_overworld_freeze_test.gd` (adds the loader-level rollback case)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: depends on 014, loader-level case, pinned rollback sequence). The developer implements against these — do not invent new test cases during implementation.*

- **AC-10 (machine)**: `game_state_swap_rollback_test.gd :: test_failure_rolls_back` (parameterized source ∈ {loader FAILED, `capture_start_snapshot() == null`, `payload_commit` false → loader FAILED})
  - Given: Overworld, IDLE; `probe_before`; the stub loader scripted `[PENDING, FAILED]` (or a stub battle mode whose capture returns `null`).
  - When: request Overworld→Battle and tick to IDLE.
  - Then: `rollback_swap` called once; `current_mode == OVERWORLD`; `phase == IDLE`; one error entry with code `&"swap_failed"` and `context.cause` naming the source; the recorder sequence is the pinned `transition_started(OVERWORLD, BATTLE)`, `mode_exited(OVERWORLD)`, `mode_entered(OVERWORLD)`, `transition_finished(OVERWORLD)`; `battle_snapshot_id == 0`; the next synthetic action reaches the Overworld mode.
- **AC-10 (loader level, in 014's file)**: `test_failure_after_detach_reattaches_same_instance`
  - Given: the real `ModeHostSceneLoader` with a fixture Overworld in a `ModeHost` node; the battle scene path pointing at a stub that fails setup.
  - When: the swap fails after `on_freezing` + `remove_child`.
  - Then: `is_same(re-attached, original)` and `is_inside_tree()`; every snapshot field equals the fixture; no orphan nodes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_swap_rollback_test.gd` and the loader-level case in `tests/unit/game_state/game_state_overworld_freeze_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (452/452 suite-wide, 0 orphans)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md` (the real loader the loader-level case needs)
- Unlocks: `production/epics/game-state-scene-flow/story-013-invalid-descriptor-stays-in-overworld.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`

---

## Completion Notes

**Files changed:**
- `src/game_state/game_state_machine.gd` — `_end_swap_phase_success()` now checks, Overworld→Battle only, whether the loader reports a live `current_mode_node()`; if so and its `capture_start_snapshot()` is `null`, it routes into the (now shared) rollback path instead of promoting `_current_mode` (ADR-0002 §7). A non-null snapshot is stored in `_battle_snapshot` (previously declared, never written). `_end_swap_phase_failure()` gained a required `cause: StringName` parameter, now in `_log.error(&"swap_failed", {..., "cause": cause})`; the `tick()` call site (loader `FAILED`) passes `&"loader_failed"`, the new capture-null branch passes `&"capture_snapshot_null"`. `mode_host_scene_loader.gd` and `scene_loader.gd` needed no changes — `rollback_swap()` was already implemented and already the mechanism this story's tests exercise.
- `tests/unit/game_state/game_state_swap_rollback_test.gd` (new) — `test_failure_rolls_back`, parametrized over the three QA sources: `loader_failed` and `payload_commit_false` are mechanically identical at the machine level (both a scripted `poll_swap() == FAILED`) and share cause `&"loader_failed"`; `capture_null` uses a `StubBattleMode` whose `capture_start_snapshot()` stays null. Asserts `rollback_swap` called once, `current_mode == OVERWORLD`, `phase == IDLE`, one `&"swap_failed"` log entry with `context.cause`, the pinned four-signal rollback sequence, `battle_snapshot_id == 0`, full debug-state restoration, and that the next synthetic action reaches a stub Overworld node (re-attached via a `mode_entered` listener standing in for the real loader's re-attach).
- `tests/unit/game_state/game_state_overworld_freeze_test.gd` — added `test_failure_after_detach_reattaches_same_instance` (real `ModeHostSceneLoader`, no `pre_setup`, so the real `stub_battle_mode.tscn` instance's `capture_start_snapshot()` stays null and the machine's own check fails it after a real `on_freezing()` + `remove_child()`); asserts `is_same` re-attach, `is_inside_tree()`, exact snapshot-field equality, the logged cause, and `mode_host.get_child_count() == 1` after draining to IDLE (no orphans). Also had to give `_run_round_trip`'s `ModeHostSceneLoader` a `pre_setup` that sets `StubBattleMode.snapshot_to_return`, since the new capture-null check would otherwise have rolled back that story's own (pre-existing) round-trip tests.
- `tests/unit/game_state/game_state_input_lock_test.gd` — `test_no_delivery_during_phase` swapped its generic counting double from `StubOverworldMode` to `StubBattleMode` (with `snapshot_to_return` set) for its Overworld→Battle case, for the same reason: the double stood in for "current mode node" regardless of target mode, and the new check would have rolled back a transition this test expects to reach `BATTLE`.

**Test count**: suite-wide 452/452 passing (448 baseline + 3 new parametrized rows + 1 new loader-level case), 0 orphans, confirmed via headless import + gdUnit4 run.

**Deviations / items owed:**
- The capture-null check is skipped when `current_mode_node()` is `null` (most pure-stub tests that don't care about this concern never set it). This is deliberate so existing signal-order/busy-rejection tests needed no change, but means the check is only exercised when a test (or production) actually supplies a node.
- `_battle_snapshot` is now populated on a successful battle entry, which is part of story 017's stated scope ("the machine calls `capture_start_snapshot()` and stores the opaque handle"). Only the capture call and null-rollback landed here; `choose_retry()` still does not call `restore_start_snapshot()` — that wiring remains story 017's job. Flagging for technical-director/story-017 implementer awareness.
- `payload_commit false` (ADR-0009 §6's distinct `SceneLoader.payload_commit` hook) is not implemented anywhere yet — no `SaveService` exists. Per the story's own wording ("stubbed through the loader as FAILED"), this case is tested purely as a second `loader_failed` row and introduces no new production code path.
