# Story 025: The open Menu stops mode time and blocks transitions, but Quit to Title still works

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§5: disable `ModeHost`, `mode_time` stops, `SceneTree.paused` not used; §4: the detached Overworld is freed on Quit to Title; Engine Compatibility item 3: `AnimationPlayer`, **open**); ADR-0005: Sprite & Camera Presentation (§4/§7: `mode_time` drives the global shader uniform; context only)
**ADR Decision Summary**: The open Menu stops mode time by disabling `ModeHost.process_mode`, never through `SceneTree.paused`. While it is open every transition is rejected except Quit to Title from the Menu itself.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Timer` and node-bound `Tween` freezing under a disabled `ModeHost` is verified on 4.7.2. **`AnimationPlayer` under a disabled `ModeHost` is still open** (ADR-0002 verification item 3; manifest advisory E7 says "probed", not yet folded in). Migration Step 1 says to confirm it here.

**Control Manifest Rules (this layer)**:
- Required: "Menu stops time by disabling `ModeHost.process_mode = PROCESS_MODE_DISABLED`. `SceneTree.paused` is never used for this."
- Forbidden: "Never use `SceneTree.paused` to implement the Menu's time stop."
- Required: "A detached Overworld is freed explicitly … on Quit to Title …"

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-20 [L]** GIVEN the Menu open over Overworld, WHEN the injected clock advances, THEN a mode timer does not advance, a transition request is rejected, and Quit to Title from the Menu succeeds.

---

## Implementation Notes

*Derived from ADR-0002 §4, §5, Engine Compatibility, and the QA gate (RC-3):*

- The machine's `mode_time` advances with `tick(delta)` only while no Menu is open. Dialogue does **not** stop it. Menu open → `loader.set_mode_time_stopped(true)`; Menu closed → `(false)`. The production loader sets `ModeHost.process_mode = PROCESS_MODE_DISABLED` / `PROCESS_MODE_INHERIT`.
- "A mode timer does not advance": in the loader-level test, a `Timer` in the stub Overworld keeps `time_left` while `ModeHost` is disabled. Headless, the clock is real frames, so `await` frames and assert `time_left` unchanged.
- **Quit to Title from the Menu** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): no new entry point. `request_transition(TITLE)` is accepted while `MENU` is the top overlay; any other target is rejected with `REJECTED_OVERLAY_BLOCKS`. Before `transition_started`, the machine pops **every** overlay top-down, emitting `overlay_closed` for each. It also re-enables `ModeHost` and frees any frozen Overworld (§4).
- **Verification item 3.** An `AnimationPlayer` playing a 1 s track on a child of a disabled `ModeHost` keeps `current_animation_position` across ≥ 10 frames and resumes after re-enabling. Record the result in Completion Notes and ask technical-director to fold it into ADR-0002's Engine Compatibility row. **If the probe fails, the story stays open** and escalates to technical-director and godot-specialist for an ADR-0002 Engine Compatibility change. A failing engine probe is never skipped or deleted.
- Never use `SceneTree.paused` or `Engine.time_scale`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 029: the Menu's entries.
- Story 039: the frozen, blurred diorama behind the Menu (screenshot).
- The Menu overlay scene (UI Framework epic).

---

## Files

- `src/game_state/game_state_machine.gd` (`mode_time`; Menu → `set_mode_time_stopped`; Quit to Title with the Menu on top)
- `src/game_state/mode_host_scene_loader.gd` (`ModeHost.process_mode` toggle)
- `tests/unit/game_state/game_state_menu_time_stop_test.gd`
- `tests/unit/game_state/game_state_animation_player_freeze_test.gd` (verification item 3)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: Quit-to-Title path pinned, overlays popped top-down, failing probe escalates). The developer implements against these — do not invent new test cases during implementation.*

- **AC-20 (time stop)**: `game_state_menu_time_stop_test.gd :: test_menu_stops_mode_time`
  - Given: OVERWORLD, `mode_time` recorded.
  - When: `open_overlay(MENU)`; tick 1.0 s in 1/60 steps; `close_overlay()`; tick 0.5 s.
  - Then: `mode_time` unchanged while the Menu is open, +0.5 (within 1e-6) after; `loader.set_mode_time_stopped(true)` then `(false)`.
- **AC-20 (Dialogue)**: `test_dialogue_does_not_stop_time` — DIALOGUE open → `mode_time` advances.
- **AC-20 (transitions)**: `test_transition_rejected_quit_to_title_ok`
  - Given: MENU over OVERWORLD; second case MENU over DIALOGUE over OVERWORLD; third case MENU over BATTLE with a frozen Overworld.
  - When: `request_transition(CAMP)`, then `request_transition(TITLE)`.
  - Then: CAMP → `REJECTED_OVERLAY_BLOCKS`, probe equal; TITLE → `OK`; `overlay_closed` for every overlay (top-down) precedes `transition_started(*, TITLE)`; `set_mode_time_stopped(false)` called; case 3: `free_frozen_overworld` called once; mode TITLE.
- **Verification item 3**: `game_state_animation_player_freeze_test.gd` (loader level)
  - Given: a real `ModeHost` with a child `AnimationPlayer` playing a 1 s track.
  - When: `ModeHost.process_mode = DISABLED` for 10 frames, then `INHERIT` for 10 frames.
  - Then: `current_animation_position` unchanged across the disabled frames (within 1e-6) and advanced after re-enabling; a `Timer` under `ModeHost` keeps `time_left` while disabled.
  - Edge cases: no `SceneTree.paused` / `Engine.time_scale` reference in `src/game_state/` (code-review item).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_menu_time_stop_test.gd` and `tests/unit/game_state/game_state_animation_player_freeze_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (479/479 suite-wide)

---

## Completion Notes

- `mode_time` already stopped advancing while `MENU in _overlay_stack` (prior
  commit); this story wired the player-visible side: `open_overlay`/`close_overlay`
  now call `loader.set_mode_time_stopped(true|false)` only for `MENU`, never
  for Dialogue or the Defeat Prompt.
- `ModeHostSceneLoader.set_mode_time_stopped()` toggles
  `ModeHost.process_mode` between `PROCESS_MODE_DISABLED` and
  `PROCESS_MODE_INHERIT`. `SceneLoader`'s base stays a no-op; `StubSceneLoader`
  gained `set_mode_time_stopped_calls: Array[bool]` for ordering assertions.
- `request_transition()` gained one special case: `target == TITLE` while
  `_overlay_stack.back() == MENU` routes to a new private `_quit_to_title()`
  instead of the ordinary `REJECTED_OVERLAY_BLOCKS`/`_REQUESTABLE_TARGETS`
  path. It pops every overlay top-down (`overlay_closed` per pop), calls
  `set_mode_time_stopped(false)` and `free_frozen_overworld()` once each, all
  before `_begin_transition()` emits `transition_started` — matching the
  2026-10-23 ruling's ordering. `_TRANSITION_TYPES` gained a `TITLE: &"fade"`
  row under `OVERWORLD`, `BATTLE` and `CAMP`; `_REQUESTABLE_TARGETS` was left
  unchanged on purpose, so `request_transition(TITLE)` stays illegal through
  the ordinary (no-overlay) path.
- **Verification item 3 result: PASSED.** `test_animation_player_and_timer_freeze_while_disabled`
  (loader-level, real `ModeHost` `Node`, real `Timer` and `AnimationPlayer`)
  confirms `current_animation_position` and `Timer.time_left` are both frozen
  across 10 frames of `PROCESS_MODE_DISABLED` and both resume after
  `PROCESS_MODE_INHERIT`. Recommend technical-director fold this into
  ADR-0002's Engine Compatibility row (item 3, currently "still open").
- Files changed: `src/game_state/game_state_machine.gd` (`_TRANSITION_TYPES`,
  `request_transition`, `open_overlay`, `close_overlay`, new `_quit_to_title`),
  `src/game_state/mode_host_scene_loader.gd` (`set_mode_time_stopped`
  override), `tests/unit/game_state/doubles/stub_scene_loader.gd`
  (`set_mode_time_stopped_calls`), new
  `tests/unit/game_state/game_state_menu_time_stop_test.gd` (6 cases: time
  stop, Dialogue does not stop time, and 3 Quit-to-Title cases — Menu over
  Overworld, Menu over Dialogue over Overworld, Menu over Battle freeing a
  frozen Overworld), new
  `tests/unit/game_state/game_state_animation_player_freeze_test.gd` (2
  cases: the engine probe, and the code-review edge case scanning
  `src/game_state/*.gd` text for a `SceneTree.paused`/`Engine.time_scale`
  reference).
- Deviation: none from the story spec. One self-inflicted snag during
  implementation — the edge-case scanner test initially failed against my
  own doc comment in `mode_host_scene_loader.gd`, which named the forbidden
  APIs literally; reworded the comment to describe the rule instead of
  quoting the API names, since the scan is a literal text search over
  `src/game_state/`.
- Items owed: none for this story. ADR-0002 Engine Compatibility item 3
  should be updated from "still open" to verified, per the result above.

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-011-quit-waits-for-transition.md`, `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`, `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-039-screenshots-menus.md`
