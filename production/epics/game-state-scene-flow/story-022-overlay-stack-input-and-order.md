# Story 022: With Dialogue then Menu stacked, only the Menu gets input, and signals fire in stack order

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§2 `OverlayHost`, top = last child; §5 Dialogue does not disable `ModeHost`; §6 deliver to the top overlay)
**ADR Decision Summary**: Overlays form a stack over the mode. Only the top overlay receives input; closing pops the top only, and `overlay_opened`/`overlay_closed` fire in stack order.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine; push/pop go through the stub loader. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`."
- Forbidden: "No system other than `GameStateMachine` (through its `SceneLoader`) may add, remove or free children of `ModeHost`/`OverlayHost`."
- Required (Input, context): "Every overlay root has a full-screen `MOUSE_FILTER_STOP` backdrop" (for the real overlays; not tested here).

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-19 [L]** GIVEN overlays stacked Dialogue then Menu, THEN only the Menu receives input. Closing the Menu returns input to Dialogue, and the open/close signals fire in stack order.

---

## Implementation Notes

*Derived from ADR-0002 §2, §5, §6:*

- `open_overlay(DIALOGUE)` then `open_overlay(MENU)`: the stub Menu counts every routed action; the stub Dialogue and stub mode count zero. `close_overlay()` pops the **top** only, after which Dialogue receives the next action.
- `overlay_stack` is returned as a **copy**, bottom first; mutating it must not change the machine.
- Overlay push/pop is a loader call (`push_overlay`/`pop_overlay`, story 001's interface additions); the stub records it. The production push into the real `OverlayHost` is story 030.
- `is_input_owner(stub_mode)` is false while any overlay is open (story 010's rule, re-asserted with a stack).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 023: which overlay may open over which.
- Story 025: the Menu time stop.
- Story 030: production overlay push/pop.

---

## Files

- `src/game_state/game_state_machine.gd` (overlay stack)
- `tests/unit/game_state/game_state_overlay_stack_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-19**: `game_state_overlay_stack_test.gd :: test_top_overlay_owns_input`
  - Given: OVERWORLD; `open_overlay(DIALOGUE)` then `open_overlay(MENU)`, each `OK`.
  - When: synthetic confirm ×2; `close_overlay()`; synthetic confirm; `close_overlay()`.
  - Then: Menu count 2, Dialogue 0, mode 0 before the first close; Dialogue count 1 after; recorder overlay events == `[opened(DIALOGUE), opened(MENU), closed(MENU), closed(DIALOGUE)]`; `overlay_stack == [DIALOGUE, MENU]` while both are open.
  - Edge cases: mutating the returned `overlay_stack` array leaves `get_debug_state().overlay_stack` unchanged; `is_input_owner(mode)` false while any overlay is open; the stub loader recorded push/pop in the same order.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_overlay_stack_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`
- Unlocks: `production/epics/game-state-scene-flow/story-023-dialogue-menu-precedence.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`, `production/epics/game-state-scene-flow/story-027-dialogue-closes-before-transition.md`, `production/epics/game-state-scene-flow/story-028-in-mode-fade.md`, `production/epics/game-state-scene-flow/story-029-battle-menu-system-entries.md`
