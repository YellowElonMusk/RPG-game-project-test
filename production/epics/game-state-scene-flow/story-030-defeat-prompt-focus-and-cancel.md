# Story 030: The Defeat Prompt opens on Retry, ignores cancel, and gets focus back after the Menu

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (grew: it also owns the production overlay push/pop and the interim confirm helper)
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004`, `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*
**UX reference**: `design/ux/interaction-patterns.md` P15 (no screen-specific UX spec exists yet; `/ux-design` for the Defeat Prompt is advisory before UI Framework work)

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6, §7; Risks: 4.6 dual focus, "focus handoff belongs to the UI Framework"); ADR-0008: UI Framework (§2 `UiContext` via `pre_setup`; §5 `FocusScope`, `UiService` grabs focus on the overlay's behalf — *interim here*)
**ADR Decision Summary**: The Defeat Prompt's lifecycle is Game State's; its look is the UI Framework's. Overlays are pushed into the real `OverlayHost` by the production `SceneLoader` with `pre_setup`. Until ADR-0008's `FocusScope` exists, the prompt manages its own focus under an INTERIM tag.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: 4.6 dual focus (keyboard/gamepad focus vs pointer). Native `Control.grab_focus()` headless is not covered by the engine reference; gdUnit4's scene runner is needed. `handle_action(...) -> bool` overrides end in an explicit `return` (4.7).

**Control Manifest Rules (this layer)**:
- Required: "Every `GameMode`/`GameOverlay` override with a typed return ends in an explicit `return`."
- Required (Input/UI): "`UiService`, not each overlay, grabs focus for an overlay" (**interim deviation**, documented in code and Completion Notes).
- Required (Input): "Every overlay root has a full-screen `MOUSE_FILTER_STOP` backdrop."
- Forbidden: "Never build a fully custom focus system in place of native `Control` focus."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-29 [L]** (rule 8, P15) GIVEN Defeat, THEN the Defeat Prompt opens with Retry focused and `cancel` changes nothing. WHEN `menu` is pressed (or focus is lost), THEN the system Menu opens over the prompt and offers Quit; WHEN the Menu closes, THEN focus is back on Retry.

---

## Implementation Notes

*Derived from ADR-0002 §6–§7, ADR-0008 §2/§5 and the QA gate (RC-4):*

- **Production overlay push/pop (QA RC-4).** No earlier story pushes into the real `OverlayHost`. This story implements `push_overlay(kind, payload)` / `pop_overlay()` on `ModeHostSceneLoader`: resolve the overlay path from `TransitionConfig`, instantiate, call the injected `pre_setup: Callable(node)` (no-op default), `setup(...)`, add as the last child of `OverlayHost`; pop frees the top. 035 and 036 reuse it.
- **Interim confirm/direction helper (QA RC-4)**, tagged `# INTERIM until ADR-0008 FocusScope / UiNavigator`. `handle_action(&"confirm", true)` emits `pressed` on `get_viewport().gui_get_focus_owner()` if it is a `BaseButton` inside this overlay or mode. Direction actions move focus with `find_valid_focus_neighbor`. Story 031 reuses it. It is needed because input-system's `ui_*` re-injection (`production/epics/input-system/story-021-nav-pressed-only-reinjection.md`) is Blocked and `FocusScope` does not exist.
- **Tests drive everything through the synthetic `ActionSource`**, never by emitting `pressed` directly, so the real routing is what passes.
- **Interim focus.** The prompt grabs focus on Retry itself when it becomes the top overlay, and again on `overlay_closed(MENU)` while it is top. Same INTERIM tag.
- `cancel`: `handle_action(&"cancel")` returns `true` and does nothing.
- Retry → `machine.choose_retry()`; Retreat → `machine.choose_retreat()`; the Retreat button exists only when `DefeatPromptPayload.offers_retreat`.
- `menu` over the prompt uses story 024's machine-level interception (`open_overlay(MENU)` with story 029's Battle entries). The Menu in the test is a stub overlay offering Quit.
- **Keep the scene minimal:** two buttons, no art. The art-bible "CLAIM DENIED" card is UI Framework work. The concrete script may later declare `var ui: UiContext`; the base `GameOverlay` names no Presentation type.
- **If headless focus proves unreliable**, the test is **not** downgraded. Escalate to godot-specialist; the fallback is a scene-runner test with a real viewport (non-headless CI runner), recorded in Completion Notes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 038: the Defeat Prompt screenshots.
- The UI Framework epic: the prompt's visuals, `UiService`, `FocusScope`, the real Menu.

---

## Files

- `src/game_state/overlays/defeat_prompt.tscn`
- `src/game_state/overlays/defeat_prompt.gd` (extends `GameOverlay`)
- `src/game_state/mode_host_scene_loader.gd` (`push_overlay` / `pop_overlay` with `pre_setup`)
- `src/game_state/interim_focus_nav.gd` (the INTERIM confirm/direction helper)
- `tests/unit/game_state/game_state_defeat_prompt_focus_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: production overlay push/pop, interim confirm helper, no downgrade on headless focus failure). The developer implements against these — do not invent new test cases during implementation.*

- **AC-29 (open)**: `game_state_defeat_prompt_focus_test.gd :: test_prompt_opens_with_retry_focused`
  - Given: the scene runner; a real `OverlayHost` + production `push_overlay`; the machine in BATTLE (stub battle mode); a synthetic source.
  - When: `report_battle_outcome(DEFEAT)`; await 2 frames.
  - Then: the top overlay is `defeat_prompt`; `gui_get_focus_owner()` == its Retry button.
- **AC-29 (cancel)**: `test_cancel_changes_nothing`
  - Then: synthetic cancel → probe equal, the prompt still top, focus still Retry.
- **AC-29 (Menu over prompt)**: `test_menu_over_prompt_and_focus_returns` (parameterized trigger ∈ {menu press, `focus_lost`})
  - Then: MENU on top of DEFEAT_PROMPT, payload `entries` contains `&"quit"`; then `close_overlay()` → await 2 frames → focus owner == Retry.
- **AC-29 (confirm)**: `test_confirm_on_retry_calls_choose_retry`
  - Then: synthetic confirm → the `choose_retry` path starts (`transition_started(BATTLE, BATTLE)`).
  - Edge cases: the Retreat button is absent when `offers_retreat` is false, present (and not focused) when true; `handle_action` overrides end in an explicit return (code-review item).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_defeat_prompt_focus_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-28: game_state_defeat_prompt_focus_test.gd, 4 test functions; full suite 554/554)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-026-focus-loss-opens-menu.md`, `production/epics/game-state-scene-flow/story-029-battle-menu-system-entries.md`
- Unlocks: `production/epics/game-state-scene-flow/story-031-title-focus-and-quit-confirm.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`, `production/epics/game-state-scene-flow/story-038-screenshots-title-prompts-error.md`, `production/epics/game-state-scene-flow/story-039-screenshots-menus.md`

---

## Completion Notes

*2026-10-28, implementation (autonomous run; the implementing agent ran out of turns before writing notes, and the main session verified and wrote them).*

- **Files**:
  - `src/game_state/overlays/defeat_prompt.tscn` and `defeat_prompt.gd` (extends `GameOverlay`);
  - `src/game_state/interim_focus_nav.gd` (the interim confirm/direction helper);
  - `push_overlay` / `pop_overlay` with `pre_setup` in `src/game_state/mode_host_scene_loader.gd`;
  - `tests/unit/game_state/doubles/stub_overlay.gd` and the new `tests/unit/game_state/fixtures/stub_overlay.tscn`;
  - `tests/unit/game_state/game_state_defeat_prompt_focus_test.gd`.
- **Tests**: four functions (`test_prompt_opens_with_retry_focused`, `test_cancel_changes_nothing`, `test_menu_over_prompt_and_focus_returns` (parametrized), `test_confirm_on_retry_calls_choose_retry` (parametrized)). Full suite 554/554, exit 0.
- **Deviations / items owed**: none recorded. Review the interim focus helper when the UI Framework epic (ADR-0008) lands.
