# Story 012: A failed swap returns to the source mode with frozen state restored and input unlocked

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md` (the real loader the loader-level case needs)
- Unlocks: `production/epics/game-state-scene-flow/story-013-invalid-descriptor-stays-in-overworld.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`
