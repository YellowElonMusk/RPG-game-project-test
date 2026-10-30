# Story 027: A transition requested by a Dialogue line closes the Dialogue before transition_started

> **Epic**: Game State & Scene Flow
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (TR table, rule 11 row: "a follow-up transition runs after the overlay closes"; §11: "The caller closes its Dialogue first (`close_overlay()`), then requests … on the same frame after `overlay_closed`")
**ADR Decision Summary**: The requester, not the machine, closes its Dialogue first and then requests the transition in the same frame. A request made with Dialogue still open is rejected with `REJECTED_OVERLAY_BLOCKS`.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`request_in_mode_fade(callback)` … close the Dialogue first (`close_overlay()`), then request the fade on the same frame after `overlay_closed`" (the same pattern for any transition).
- Required: "Signals fire in exactly this order for a transition …"
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [x] **AC-32 [L]** (rule 11) GIVEN Dialogue open, WHEN its line requests a transition, THEN the Dialogue overlay closes (`overlay_closed`) before `transition_started` fires.

---

## Implementation Notes

*Derived from ADR-0002 §11 and the rule 11 TR row:*

- ADR-0002 §11 pins the requester-closes-first design. The stub Dialogue overlay's "line" calls `machine.close_overlay()` and then `machine.request_transition(CAMP, valid)` with no tick between; both return `OK`.
- Keep the ordering assertion strict: sequence-recorder indices, not just "both fired".
- A request made *without* closing first is rejected with `REJECTED_OVERLAY_BLOCKS` and an unchanged probe.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 028: the in-mode fade.
- Story 036: dialogue after a Victory return.

---

## Files

- `tests/unit/game_state/game_state_dialogue_then_transition_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-32 (close then request)**: `game_state_dialogue_then_transition_test.gd :: test_close_then_request_same_frame`
  - Given: OVERWORLD with a stub Dialogue overlay whose "line" calls `machine.close_overlay()` then `machine.request_transition(CAMP, valid)`, with no tick between.
  - When: the line runs.
  - Then: both `OK`; recorder `index(overlay_closed(DIALOGUE)) < index(transition_started(OVERWORLD, CAMP))`.
- **AC-32 (no close)**: `test_request_without_close_rejected`
  - Then: `request_transition` while Dialogue is open → `REJECTED_OVERLAY_BLOCKS`, probe equal.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_dialogue_then_transition_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing: `tests/unit/game_state/game_state_dialogue_then_transition_test.gd` (game_state unit 184/184; with overworld + game_state integration 242/242, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`

---

## Completion Notes

**Completed**: 2026-10-30
- AC already held; tests added. The 'line' is a test function standing in for the future Dialogue system.
- Files: tests/unit/game_state/game_state_dialogue_then_transition_test.gd
