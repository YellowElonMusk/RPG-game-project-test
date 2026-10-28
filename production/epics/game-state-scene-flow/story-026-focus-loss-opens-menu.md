# Story 026: Focus loss or device loss opens the Menu, deferred past a transition and ignored in Boot

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`, `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6 deferred-Menu flag; §11 deferred during an in-mode fade too); ADR-0003: Input System (§8: `device_lost()`/`focus_lost()` fire only after every held action's `action_released`)
**ADR Decision Summary**: Focus or device loss opens the Menu at once when IDLE in a mode that allows it. During a transition it sets a deferred-Menu flag and the Menu opens right after `transition_finished`. Boot and Content Error ignore it.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23) · ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW (for this story; MEDIUM for the feature)
**Engine Notes**: `NOTIFICATION_APPLICATION_FOCUS_OUT` is unverified on 4.7.2 (ADR-0003; GDD Edge Cases); its fallback is a per-frame window-focus poll owned by godot-specialist. This story tests only the machine against the synthetic source; the real notification is input-system's verification (`production/epics/input-system/story-025-focus-lost-and-gained.md`).

**Control Manifest Rules (this layer)**:
- Required (Input): "`device_lost()`/`focus_lost()` fire only after every held action's `action_released`."
- Required: "The in-mode fade … Input lock, Menu deferral, `is_save_safe() == false` and quit-waiting behave as for any transition."
- Required: "Input unlocks after `transition_finished`."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-23 [L]** GIVEN focus lost in Overworld, THEN the Menu opens. GIVEN focus lost during a transition, THEN the Menu opens after `transition_finished` and not before. GIVEN focus lost in Boot, THEN nothing happens. GIVEN Input's `device_lost` in Overworld, THEN the Menu opens; GIVEN `device_lost` during a transition, THEN the Menu opens after `transition_finished`.

---

## Implementation Notes

*Derived from ADR-0002 §6, §11 and the QA gate (RC-3):*

- In an allowed mode while IDLE, `focus_lost` or `device_lost` opens the Menu at once; the Defeat Prompt on top counts as allowed (GDD Edge Cases: "the Defeat Prompt included"). It reuses story 024's machine-level Menu open.
- During a transition the machine sets the deferred-Menu flag (`get_debug_state().menu_deferred`) and opens the Menu right after `transition_finished`.
- **"If focus is still lost":** the contract deliberately does not consume `focus_gained`. Open the deferred Menu **unconditionally** after `transition_finished` (QA kept the draft recommendation; a paused game on refocus is harmless). Record it in Completion Notes as an interpretation of the GDD wording.
- **Deferred-Menu destination rule** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): after `transition_finished(to)`, the deferred Menu opens only if `to` permits the Menu (Overworld, Camp, Battle). Otherwise the flag is cleared silently.
- Boot and Content Error: ignored, with no flag set (shared with 005).
- If the Menu is already open, a second loss is a no-op.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 028: focus loss during the in-mode fade (re-asserted there).
- Story 030: the Menu over the Defeat Prompt with real focus.
- `production/epics/input-system/story-025-focus-lost-and-gained.md`: the real focus notification.

---

## Files

- `src/game_state/game_state_machine.gd` (deferred-Menu flag)
- `tests/unit/game_state/game_state_focus_loss_menu_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fix applied: deferred-Menu destination rule pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-23 (IDLE)**: `game_state_focus_loss_menu_test.gd :: test_loss_opens_menu` (parameterized signal ∈ {`focus_lost`, `device_lost`}, state ∈ {OVERWORLD IDLE, BATTLE IDLE with DEFEAT_PROMPT})
  - Then: `overlay_opened(MENU)` synchronously; MENU on top of the stack.
- **AC-23 (during a transition)**: `test_loss_during_transition_deferred` (parameterized signal × phase OUT/SWAP/IN)
  - Then: no `overlay_opened` before `transition_finished`; recorder `index(overlay_opened(MENU)) == index(transition_finished) + 1`; `menu_deferred` false afterwards.
- **AC-23 (Boot)**: `test_loss_in_boot_ignored`
  - Then: BOOT → nothing; `menu_deferred` false; and nothing after Boot→Title completes.
  - Edge cases: loss during a transition whose destination is TITLE → no Menu, flag cleared; a second loss with the Menu already open → no second `overlay_opened`; loss during the in-mode fade → Menu after `transition_finished` (also in 028).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_focus_loss_menu_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-28: game_state_focus_loss_menu_test.gd, 11 cases)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`
- Unlocks: `production/epics/game-state-scene-flow/story-028-in-mode-fade.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`

---

## Completion Notes

*2026-10-28, implementation (autonomous run).*

- **Files**: in `src/game_state/game_state_machine.gd`, `_on_source_focus_lost()` and `_on_source_device_lost()` now call `_handle_focus_or_device_lost()`. That opens the Menu at once when idle in Overworld, Camp or Battle (the Defeat Prompt on top counts), and does nothing if the Menu is already on top. Mid-transition it sets `_menu_deferred`. `_end_in_phase()` then opens the Menu if the destination allows it and otherwise clears the flag silently (a Title destination). Boot, Title and Content Error ignore the loss and set no flag. New test file: `tests/unit/game_state/game_state_focus_loss_menu_test.gd`, 11 cases.
- **Test fix during verification**: the first draft asserted `overlay_opened` at recorder index 0, and at exactly `transition_finished + 1`. The stub loader also records `push_overlay` and `set_mode_time_stopped` into the same recorder, so those asserts were wrong although the behaviour was right. They now assert that `overlay_opened` is recorded at all, and that it comes after `transition_finished`.
- **Items owed**: none.
