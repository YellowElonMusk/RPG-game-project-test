# Story 031: Title opens on New Game with Continue disabled, and Quit asks for confirmation with No focused

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*
**UX reference**: `design/ux/interaction-patterns.md` P4, P15 (no screen-specific UX spec exists yet; `/ux-design` for Title and the Quit confirmation is advisory before UI Framework work)

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§2: mode scenes extend `GameMode`; rule 12 via Key Interfaces `request_quit`); ADR-0008: UI Framework (§5 focus, *interim*); ADR-0009: Save/Load & Settings (§4 `has_unsaved_progress()` drives the quit wording; before Save/Load: "all progress will be lost")
**ADR Decision Summary**: Title is a `GameMode` scene. Quit opens a confirmation panel that belongs to Title (not a machine overlay); Yes calls `machine.request_quit()`, whose injected hook is the quit spy in tests.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0008 2026-10-22 · ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: 4.6 dual focus; `@abstract` subclass; typed-return overrides need an explicit `return` (4.7).

**Control Manifest Rules (this layer)**:
- Required: "Every `GameMode`/`GameOverlay` override with a typed return ends in an explicit `return`."
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`."
- Forbidden: "Never build a fully custom focus system in place of native `Control` focus."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-30 [L]** (rule 12) GIVEN Title, THEN New Game is focused and Continue is disabled (until Save/Load exists). WHEN Quit is chosen, THEN a confirmation opens with No focused; `cancel` closes it without quitting; Yes calls the injected quit handler exactly once (a quit spy in the harness).

---

## Implementation Notes

*Derived from ADR-0002 §2, ADR-0008 §5, ADR-0009 §4 and the QA gate (RC-3, RC-4):*

- `title_mode.gd` extends `GameMode`: New Game → `request_transition(OVERWORLD, …)`; Continue disabled; Settings goes nowhere until Settings exists; Quit → the confirmation.
- `quit_confirm` is a **child panel of Title, not a machine overlay** (the Overlays table has no Quit overlay). Reuse the same scene for the Menu's Quit confirmation when the UI Framework builds the Menu.
- **Every step is driven through the synthetic `ActionSource`**, using story 030's interim confirm/direction helper (`# INTERIM until ADR-0008 FocusScope / UiNavigator`). Interim focus handling as in 030.
- **Quit latch** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): the quit hook fires at most once per machine lifetime, so Yes pressed twice in one frame still produces one call.
- Continue: disabled **and** carries a lock glyph and its unlock reason on focus (P4, GDD rule 12). The glyph is screenshot evidence (038); this test asserts `disabled == true` and focus on New Game.
- Title's strings are player-facing and go through ADR-0013 localization when that epic lands. Note it; build no string tables here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 038: the Title and Quit confirmation screenshots.
- The Menu's Quit confirmation (UI Framework epic).

---

## Files

- `src/game_state/modes/title_mode.tscn`, `src/game_state/modes/title_mode.gd`
- `src/game_state/modes/quit_confirm.tscn`, `src/game_state/modes/quit_confirm.gd`
- `tests/unit/game_state/game_state_title_quit_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: depends on 030's helper, quit latch, everything through the synthetic source). The developer implements against these — do not invent new test cases during implementation.*

- **AC-30 (initial focus)**: `game_state_title_quit_test.gd :: test_title_initial_focus`
  - Given: the scene runner; the production loader instances `title_mode.tscn` under `ModeHost` through Boot→Title (stub catalog READY).
  - When: await 2 frames after `transition_finished(TITLE)`.
  - Then: focus owner == New Game; `Continue.disabled == true`.
- **AC-30 (Quit flow)**: `test_quit_confirm_flow`
  - When: navigate (synthetic move down ×N) to Quit, confirm; await 2 frames.
  - Then: the confirmation is visible and focus owner == No; synthetic cancel → confirmation hidden, `quit_spy.calls == 0`, focus back on Quit; reopen, move to Yes, confirm ×2 in one frame → `quit_spy.calls == 1`.
  - Edge cases: No + confirm → closes, no quit; New Game confirm → `request_transition(OVERWORLD)` recorded.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_title_quit_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-28: game_state_title_quit_test.gd, 4 cases; full suite 558/558)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-011-quit-waits-for-transition.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md` (the interim confirm/direction helper)
- Unlocks: `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-038-screenshots-title-prompts-error.md`

---

## Completion Notes

*2026-10-28, implementation (autonomous run; the implementing agent ran out of turns, and the main session fixed, verified and wrote these notes).*

- **Files**:
  - `src/game_state/modes/title_mode.tscn` and `title_mode.gd` (`TitleMode extends GameMode`: New Game focused on open; Continue disabled but focusable; Quit opens `QuitConfirm`; New Game confirm requests Overworld);
  - `src/game_state/modes/quit_confirm.tscn` and `quit_confirm.gd` (a reusable Yes/No child panel, never a machine overlay; opens on No; `cancel` closes it; Yes relies on `request_quit()`'s latch);
  - `tests/unit/game_state/game_state_title_quit_test.gd` (4 cases).
- **Fixes the main session made**:
  1. `InterimFocusNav.route_*(self as Control)` was a parse error on 4.7.2, because the script extends `GameMode` (a `Node`) even though the scene root is a `Control`. It now routes through the `Buttons` container.
  2. `_ready()` read a button field that is only assigned in `setup()`. It now resolves `%NewGameButton` itself.
  3. Mode scenes get `setup()` only through the loader's `pre_setup` closure, and the test passed none. The test now passes `pre_setup = func(mode, payload): mode.setup(machine, payload)`. **Story 035's `GameRoot` must wire the same closure.**
  4. The test looked up `%YesButton`/`%NoButton` from the Title root, but those unique names belong to the `QuitConfirm` sub-scene. They now resolve from `quit_confirm`.
  5. Headless geometric focus search did not reach Yes from No, so `quit_confirm.tscn` now sets explicit focus neighbours.
- **Items owed**: to story 035, the `GameRoot` `pre_setup` wiring above.
