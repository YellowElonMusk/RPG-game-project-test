# Story 018: The Defeat Prompt offers Retreat only when retreat_allowed, with no stale flag after Retry

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§7–§8: `ChapterMode` builds every descriptor with `retreat_allowed = false` until Camp exists)
**ADR Decision Summary**: The machine decides what the Defeat Prompt offers and hands it over as plain data (`DefeatPromptPayload`). The offer is computed fresh on every Defeat from the stored descriptor, never cached across a Retry.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`GameStateMachine` … every collaborator enters only through `_init`" (the payload is plain data, not a reference into the machine).
- Forbidden: "No system other than `GameStateMachine` (through its `SceneLoader`) may add, remove or free children of `ModeHost`/`OverlayHost`."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-16 [L]** GIVEN `retreat_allowed = false`, THEN the Prompt offers only Retry. GIVEN `true` followed by a Retry, THEN a later Defeat in the same battle still offers Retreat (no stale flag).

---

## Implementation Notes

*Derived from ADR-0002 §7–§8 and the QA gate (RC-2):*

- "Offers" is asserted on the **payload the machine passes to `open_overlay(DEFEAT_PROMPT, payload)`** (`DefeatPromptPayload.offers_retreat: bool`), plus `choose_retreat()` being rejected when not offered. The visible button state is 030/038.
- The offer is computed **fresh on every Defeat**, and the payload is a new object each time.
- **The fixture registers a camp (QA RC-2).** Story 021 later adds camp availability to the offer (`retreat_allowed and a camp exists`), so the fixture calls `register_camp("camp_a")` in Overworld before battle entry. That keeps this test valid after 021 lands. Leave a comment in the fixture saying so.
- **Sequencing note.** `register_camp` is specified and tested by story 020, which comes after this story. If 020 has not landed, add only its minimal body here (Overworld + IDLE sets `last_camp_id`); 020 adds the guards, logging, outside-write rejection and the unsaved-progress mark, and owns all of their tests.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 020: `register_camp` in full and the registered-camp Retreat path.
- Story 021: the region-default fallback and the no-camp non-offer.
- Story 030: the prompt scene.

---

## Files

- `src/game_state/defeat_prompt_payload.gd` (`offers_retreat: bool`)
- `src/game_state/game_state_machine.gd` (offer computation; `choose_retreat` rejection when not offered)
- `tests/unit/game_state/game_state_retreat_offer_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fix applied: fixture registers a camp). The developer implements against these — do not invent new test cases during implementation.*

- **AC-16 (offer)**: `game_state_retreat_offer_test.gd :: test_offer_follows_descriptor`
  - Given: `register_camp("camp_a")` in Overworld; BATTLE entered with `retreat_allowed` (a) false, (b) true.
  - When: `report_battle_outcome(DEFEAT)`.
  - Then: the `DefeatPromptPayload` passed to `open_overlay` has `offers_retreat` == (a) false / (b) true; (a) `choose_retreat()` → rejected, probe equal.
- **AC-16 (no stale flag)**: `test_no_stale_flag_after_retry`
  - Given: case (b).
  - When: Defeat → `choose_retry()` → run to IDLE → Defeat again.
  - Then: `offers_retreat` true both times.
  - Edge cases: the payload is a new object on each Defeat (not `is_same`).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_retreat_offer_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`, `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`
