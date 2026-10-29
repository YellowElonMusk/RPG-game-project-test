# Story 024: The Menu cannot be opened by input during a transition, in Boot or in Content Error

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`, `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6 `menu` action routing; §10 terminal)
**ADR Decision Summary**: The machine itself turns the `menu` action into a Menu open, only where rule 10 allows it and only while IDLE. During a transition, in Boot, Title or Content Error, the Menu does not open.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Synthetic source. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required (Input): "`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held."
- Required: "Input unlocks after `transition_finished`."
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-22 [L]** GIVEN a running transition, Boot or Content Error, WHEN the Menu is requested by input, THEN it is rejected.

---

## Implementation Notes

*Derived from ADR-0002 §6, §10 and the QA gate (RC-3):*

- **`menu` interception** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): the machine handles `action_pressed(&"menu")` itself, **before routing**. It calls its own `open_overlay(MENU, payload)` when the rule-10 list allows it (Overworld, Camp, Battle, including Battle with the Defeat Prompt on top), and the action is **never delivered** to the mode or overlay. This is what lets the Menu open over the Defeat Prompt (030) and keeps the rule in one place.
- "By input" means the synthetic source emits `action_pressed(&"menu")`. Cases: during OUT/SWAP/IN (dropped by the lock; `REJECTED_BUSY` if `open_overlay` is called directly), in Boot and Title (not in the Menu's "can open over" list → `REJECTED_INVALID_PAIR`, the pinned overlay-not-allowed code from story 023), in Content Error (`REJECTED_TERMINAL`).
- Action names come from ADR-0003's `InputActions` constants once the input-system epic lands. Until then use a test-local `MENU_ACTION = &"menu"` with a TODO to switch to the constant.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: focus/device loss opening the Menu.
- Story 029: what the Menu offers.

---

## Files

- `src/game_state/game_state_machine.gd` (`menu` interception)
- `tests/unit/game_state/game_state_menu_gating_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fix applied: machine-level `menu` interception pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-22 (rejected)**: `game_state_menu_gating_test.gd :: test_menu_input_rejected` (parameterized BOOT, CONTENT_ERROR, TITLE, OUT, SWAP, IN)
  - Given: the machine in the state; the synthetic source bound.
  - When: the source emits `action_pressed(MENU_ACTION)` (test-local `&"menu"` with a TODO → `InputActions` constant).
  - Then: no `overlay_opened` recorded; probe equal; the mode/overlay `handle_action` count for `&"menu"` == 0.
- **AC-22 (allowed)**: `test_menu_input_opens_in_allowed_modes`
  - Given: OVERWORLD, CAMP, BATTLE (IDLE).
  - Then: `overlay_opened(MENU)`, and the mode never receives `&"menu"`.
  - Edge cases: direct `open_overlay(MENU)` during a transition → `REJECTED_BUSY`; in CONTENT_ERROR → `REJECTED_TERMINAL`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_menu_gating_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (533/533 suite-wide, 0 failures, 0 orphans)

---

## Completion Notes

**Files**:
- `src/game_state/game_state_machine.gd` — added `_MENU_ACTION` (test-local
  `&"menu"` constant with a TODO to switch to ADR-0003's `InputActions.MENU`)
  and `_MENU_ALLOWED_MODES` (`[OVERWORLD, CAMP, BATTLE]`, rule 10). Changed
  `_on_source_action_pressed` to intercept `&"menu"` before
  `_dispatch_discrete_action` and route it to a new private
  `_handle_menu_action()`, which calls `open_overlay(MENU, null)` only while
  `phase == IDLE` and `_current_mode` is in the allowed list — every other
  case (a running transition, Boot, Title, Content Error) silently drops the
  request. `action_released(&"menu")` is left unintercepted (not in scope;
  the ADR summary names only `action_pressed`).
- `tests/unit/game_state/game_state_menu_gating_test.gd` (new) —
  `test_menu_input_rejected` (parameterized BOOT, CONTENT_ERROR, TITLE, OUT,
  SWAP, IN) and `test_menu_input_opens_in_allowed_modes` (OVERWORLD, CAMP,
  BATTLE, BATTLE-with-Defeat-Prompt-on-top, plus the two direct-`open_overlay`
  edge cases: REJECTED_BUSY mid-transition, REJECTED_TERMINAL in Content
  Error).

**Test count**: 533/533 passing (526 baseline + 7 new: 6 parameterized rows
+ 1 multi-stage test), 0 errors, 0 orphans.

**Deviations / notes**:
- Story 023 (the full overlay "can open over" table, incl. `REJECTED_INVALID_PAIR`
  for a direct `open_overlay(MENU)` in Boot/Title) is deferred pending
  Dialogue. This story does not add that table to `open_overlay()` itself —
  only the input-interception path's own local allow-list, per the
  Implementation Notes' framing ("the pinned overlay-not-allowed code from
  story 023" describes the conceptual rejection, not a dependency this story
  had to build). Direct `open_overlay(MENU)` in Boot/Title therefore still
  succeeds unconditionally today, same as before this story — untouched,
  since `Files` scoped this story to the `menu` interception only. Flagging
  for story 023 / technical-director.
- No items owed within this story's stated scope.

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-005-content-error-rejects-all-but-quit.md`, `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`, `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-026-focus-loss-opens-menu.md`, `production/epics/game-state-scene-flow/story-029-battle-menu-system-entries.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`, `production/epics/game-state-scene-flow/story-031-title-focus-and-quit-confirm.md`

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing
**Deviations**: Advisory — direct `open_overlay(MENU)` from Boot/Title still succeeds unconditionally; the full "can open over" pair table belongs to deferred story 023. This story scoped itself to the menu-action interception path only, per its own Files list.
**Test Evidence**: `tests/unit/game_state/game_state_menu_gating_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
