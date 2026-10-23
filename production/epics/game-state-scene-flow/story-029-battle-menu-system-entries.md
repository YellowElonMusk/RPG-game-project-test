# Story 029: In Battle the Menu offers only settings and quit

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

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§5–§6: the Menu overlay; payload to `open_overlay`)
**ADR Decision Summary**: The machine decides what the Menu offers and passes it as plain data in the `open_overlay(MENU, payload)` payload; the Menu scene only renders it. In Battle that is settings and quit only.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`GameStateMachine` … every collaborator enters only through `_init`" (the payload is data, not a callback into the machine).
- Required (UI, context): "The production `SceneLoader` and the `OverlayHost` push take an injected `pre_setup: Callable(node)` … `GameMode`/`GameOverlay` stay unchanged."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-31 [L]** (rule 10) GIVEN Battle, THEN the Menu offers only settings and quit (no party, no Codex).

---

## Implementation Notes

*Derived from ADR-0002 §5–§6 and the QA gate:*

- **Pinned: `MenuPayload.entries: Array[StringName]`**, asserted as an exact ordered list. A `scope` enum may exist alongside, but the AC is asserted on `entries`.
  - Battle, including Battle with the Defeat Prompt on top: `[&"settings", &"quit"]`.
  - Overworld and Camp: `[&"pause", &"party", &"codex", &"settings", &"quit"]`.
- The payload is plain data (no Callable fields). The Menu overlay scene (UI Framework, not this epic) renders it, which keeps AC-31 a headless [L] test.
- The visible Battle system menu is screenshot evidence in story 039.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 039: the Battle system menu screenshot.
- The Menu overlay scene (UI Framework epic).

---

## Files

- `src/game_state/menu_payload.gd` (`entries: Array[StringName]`)
- `src/game_state/game_state_machine.gd` (builds the payload per mode)
- `tests/unit/game_state/game_state_battle_menu_scope_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fix applied: `entries` list pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-31**: `game_state_battle_menu_scope_test.gd :: test_menu_entries_per_mode` (parameterized)
  - Given: (a) BATTLE; (b) BATTLE with DEFEAT_PROMPT; (c) OVERWORLD; (d) CAMP.
  - When: a synthetic menu press (or `focus_lost`).
  - Then: the payload passed to `open_overlay(MENU, …)` has `entries == [&"settings", &"quit"]` in (a)(b), and `== [&"pause", &"party", &"codex", &"settings", &"quit"]` in (c)(d), order checked.
  - Edge cases: no `&"party"` or `&"codex"` in any Battle case; the payload is plain data (no Callable fields).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_battle_menu_scope_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`, `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`
- Unlocks: `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`, `production/epics/game-state-scene-flow/story-039-screenshots-menus.md`
