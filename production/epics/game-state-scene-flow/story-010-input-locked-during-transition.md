# Story 010: Input during out, swap and in reaches nobody; the first action after transition_finished is delivered

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6 input routing; Key Interfaces `bind_action_source`, `is_input_owner`, `get_move_vector`); ADR-0003: Input System (§1: the resolver satisfies `ActionSource` directly)
**ADR Decision Summary**: The machine is the only consumer of `ActionSource`. It drops discrete actions while `phase != IDLE`, otherwise delivers to the top overlay or the mode. Movement is polled through `get_move_vector(caller)`, which returns zero unless the caller owns input. Input unlocks after `transition_finished`.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Synthetic source only; the real resolver is wired in story 035.

**Control Manifest Rules (this layer)**:
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`. Modes and overlays never reference the Input System directly."
- Forbidden: "Never let a mode or overlay reach the Input System directly — the `mode_direct_input_access` stance."
- Required: "Input unlocks after `transition_finished`."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-8 [L]** GIVEN synthetic input injected during each of *out*, *swap* and *in*, THEN the mode and every overlay receive zero actions. The first action after `transition_finished` is delivered.

---

## Implementation Notes

*Derived from ADR-0002 §6 and ADR-0003 §1:*

- Add `bind_action_source(source)`, routing, `get_move_vector(caller)` and `is_input_owner(caller)`.
- Discrete actions are dropped while `phase != IDLE`; otherwise they go to the top overlay's `handle_action`, or to the current mode's when no overlay is open.
- Movement is polled: `get_move_vector(caller)` forwards to the source and returns `Vector2.ZERO` unless the caller owns input. A caller does not own input during a transition or while any overlay is open. Assert both the discrete and the continuous path in each phase.
- **Unlock order:** the lock clears **before** `transition_finished` is emitted, so an action injected from a `transition_finished` listener is delivered.
- Consumed: `action_pressed`, `action_released`, `focus_lost`, `device_lost`, plus `get_move_vector()`. **Not** consumed: `action_held`, `device_restored`, `focus_gained`, `active_device_changed`. The synthetic source emits them too, and the test asserts nothing reacts.
- **Open design question (game-designer, not a gate item):** an action pressed before a transition and released during it has its `action_released` dropped. A receiver that tracks held state from press/release pairs would be left holding it. This story tests the AC as written; record the question in Completion Notes.
- Stub modes/overlays count `handle_action` calls; use `auto_free`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 022: routing with an overlay stack.
- Story 024: `menu` interception.
- Story 026: focus and device loss.

---

## Files

- `src/game_state/game_state_machine.gd` (`bind_action_source`, routing, `get_move_vector`, `is_input_owner`)
- `tests/unit/game_state/game_state_input_lock_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-8 (lock)**: `game_state_input_lock_test.gd :: test_no_delivery_during_phase` (parameterized OUT, SWAP, IN)
  - Given: Overworld with a counting stub mode; Overworld→Battle stopped in the phase; the synthetic source bound.
  - When: the source emits `action_pressed(&"confirm")`, `action_released(&"confirm")`; the source move vector is set to (1, 0).
  - Then: the stub mode's and any stub overlay's `handle_action` counts == 0; `get_move_vector(stub_mode) == Vector2.ZERO`; `is_input_owner(stub_mode) == false`.
- **AC-8 (unlock)**: `test_first_action_after_finished_delivered`
  - Given: a listener on `transition_finished` that makes the source emit `action_pressed(&"confirm")` synchronously.
  - When: the transition completes.
  - Then: the destination mode's `handle_action` count == 1 for that action (lock cleared before the emit).
  - Edge cases: `action_held`, `device_restored`, `focus_gained`, `active_device_changed` emitted while IDLE → no receiver reacts; with an overlay open, `get_move_vector(mode) == ZERO` and the overlay gets the discrete actions.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_input_lock_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing — `tests/unit/game_state/game_state_input_lock_test.gd`, 443/443 suite-wide, 0 orphans.

---

## Completion Notes

**Files changed:**
- `src/game_state/game_state_machine.gd` — `bind_action_source` now connects `action_pressed`/`action_released`/`focus_lost`/`device_lost` on the duck-typed source (and disconnects a prior one on rebind); `_dispatch_discrete_action` drops while `phase != IDLE`, else routes to `_loader.current_overlay_node()` when the overlay stack is non-empty, else to `_loader.current_mode_node()`. `is_input_owner`/`get_move_vector` unchanged (already correct from an earlier story).
- `src/game_state/scene_loader.gd` — added `current_overlay_node() -> Node` (default `null`), mirroring `current_mode_node()`, so the machine has a destination for overlay routing. `ModeHostSceneLoader` inherits the default unchanged (real `OverlayHost` wiring is story 030).
- `tests/unit/game_state/doubles/stub_scene_loader.gd` — added `current_overlay_node_value` + override.
- `tests/unit/game_state/doubles/stub_overlay.gd`, `stub_overworld_mode.gd`, `stub_battle_mode.gd`, `stub_camp_mode.gd` — added `handle_action_count`/`last_action`/`last_pressed` counters.
- `tests/unit/game_state/doubles/synthetic_action_source.gd` — added `action_held`, `focus_gained`, `device_restored`, `active_device_changed` signals + emit helpers, so a test can prove the machine does not react to the NOT-consumed set.
- `tests/unit/game_state/game_state_input_lock_test.gd` — new, 2 tests expanding to 4 cases (`test_no_delivery_during_phase` ×3 phases, `test_first_action_after_finished_delivered` ×1, with the unlock test's body also covering both documented edge cases).

**Test count**: full suite 443/443 passing, 0 errors/failures/orphans (up from 439 baseline + 4 new cases).

**Deviations from the Files list:** the story's Files section named only `game_state_machine.gd` and the test; reaching "the top overlay" for routing needed a `SceneLoader.current_overlay_node()` interface addition (mirroring the existing `current_mode_node()`), so `scene_loader.gd` and the doubles above were extended too, per this run's "reuse and extend only where needed" guidance.

**Open design question carried forward (not a gate item, per the story):** an action pressed before a transition and released during it has its `action_released` dropped (never dispatched), same as any other mid-transition input. A receiver tracking held state from press/release pairs would be left holding it. Unresolved — for game-designer review.

**Items owed:** none for AC-8 as written. `focus_lost`/`device_lost` are connected (consumed per the contract) but intentionally inert here — story 026 adds the menu-opening behavior.

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-019-repeated-retry-one-restart.md`, `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-026-focus-loss-opens-menu.md`, `production/epics/game-state-scene-flow/story-028-in-mode-fade.md`

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing (AC-8)
**Deviations**: Advisory — the Files list named only `game_state_machine.gd` and the test, but routing to "the top overlay" needed `SceneLoader.current_overlay_node()` (mirroring the existing `current_mode_node()`), so `scene_loader.gd` and its doubles were extended too.
**Test Evidence**: `tests/unit/game_state/game_state_input_lock_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
