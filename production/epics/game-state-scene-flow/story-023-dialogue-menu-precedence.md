# Story 023: Dialogue cannot open over the Menu, but the Menu can open over Dialogue

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

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (TR table, rule 11 row: `REJECTED_OVERLAY_BLOCKS`)
**ADR Decision Summary**: Dialogue requested over the Menu is rejected with `REJECTED_OVERLAY_BLOCKS` and not queued; the requester retries after `overlay_closed(MENU)`. The Menu may open over Dialogue.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state" (the same probe).
- Required: "Menu stops time by disabling `ModeHost.process_mode` …" (context: Dialogue does not; see 025).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [x] **AC-21 [L]** GIVEN the Menu open, WHEN Dialogue requests to open, THEN it is rejected. GIVEN Dialogue open, WHEN the Menu opens, THEN it succeeds.

---

## Implementation Notes

*Derived from the ADR-0002 TR table and the QA gate (RC-3):*

- Dialogue over the Menu → `REJECTED_OVERLAY_BLOCKS` with an unchanged probe. The machine does **not** queue the request (GDD Edge Cases: "The Dialogue system retries after `overlay_closed(Menu)`").
- The Overlays table also restricts *where* each opens: Dialogue over Overworld/Camp only; the Menu over Overworld/Camp/Battle; the Defeat Prompt over Battle on Defeat only. Add rejection cases for Dialogue in Battle (banter is not an overlay, rule 11), Title and Boot, and for a direct Defeat Prompt open in Overworld.
- **Overlay-not-allowed result code** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): an overlay kind not allowed over the current mode returns **`REJECTED_INVALID_PAIR`**. (Dialogue blocked by the Menu stays `REJECTED_OVERLAY_BLOCKS`.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 024: the Menu opened by input.
- Story 027: Dialogue followed by a transition.

---

## Files

- `src/game_state/game_state_machine.gd` (overlay "can open over" table)
- `tests/unit/game_state/game_state_overlay_precedence_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; the overlay-not-allowed code is now pinned, so tests assert `REJECTED_INVALID_PAIR` rather than `!= OK`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-21**: `game_state_overlay_precedence_test.gd :: test_dialogue_rejected_over_menu` / `test_menu_over_dialogue_ok`
  - Given: (a) OVERWORLD with MENU open; (b) OVERWORLD with DIALOGUE open.
  - When: (a) `open_overlay(DIALOGUE)`; (b) `open_overlay(MENU)`.
  - Then: (a) `REJECTED_OVERLAY_BLOCKS`, probe equal, no queued retry (closing the Menu opens nothing); (b) `OK`.
  - Edge cases: DIALOGUE in BATTLE, TITLE, BOOT → `REJECTED_INVALID_PAIR` (pinned) and probe equal; DEFEAT_PROMPT opened directly in OVERWORLD → rejected.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_overlay_precedence_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing: `tests/unit/game_state/game_state_overlay_precedence_test.gd` (game_state unit 184/184; with overworld + game_state integration 242/242, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
- Built at machine level against OverlayKind.DIALOGUE (the interim line dialogue already uses it); no real Dialogue system needed.
- _OVERLAY_ALLOWED_MODES table in open_overlay(): Dialogue over Overworld/Camp, Menu over Overworld/Camp/Battle, Defeat Prompt never via open_overlay -> REJECTED_INVALID_PAIR. Dialogue with Menu on the stack -> REJECTED_OVERLAY_BLOCKS, not queued.
- Files: src/game_state/game_state_machine.gd, tests/unit/game_state/game_state_overlay_precedence_test.gd
