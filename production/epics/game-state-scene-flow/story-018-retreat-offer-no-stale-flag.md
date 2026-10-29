# Story 018: The Defeat Prompt offers Retreat only when retreat_allowed, with no stale flag after Retry

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

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

**Status**: [x] Created, passing (465/465 suite tests pass, 0 orphans)

---

## Completion Notes

**Files changed**:
- `src/game_state/defeat_prompt_payload.gd` (new) — `offers_retreat: bool`.
- `src/game_state/game_state_machine.gd` — DEFEAT case in `report_battle_outcome`
  now builds a fresh `DefeatPromptPayload` and passes it to `_loader.push_overlay`
  (was `null`); added private `_offers_retreat()` (`_current_descriptor != null and
  _current_descriptor.retreat_allowed`), used by both the DEFEAT case and
  `choose_retreat()`'s existing rejection guard so the two can never disagree.
- `tests/unit/game_state/doubles/stub_scene_loader.gd` — added
  `last_push_overlay_payload: RefCounted`, captured in `push_overlay()`, so a
  test can inspect what the machine handed the loader (previously discarded as
  `_payload`).
- `tests/unit/game_state/game_state_retreat_offer_test.gd` (new) —
  `test_offer_follows_descriptor` (parametrized, cases a/b) and
  `test_no_stale_flag_after_retry`, per the QA Test Cases above.

**Test count**: 3 new test cases (1 parametrized function x2 cases + 1 plain
function). Suite: 465/465 pass, 0 failures, 0 orphans (was 462/462).

**Deviations**: none. `choose_retreat()`'s reject-when-not-offered guard
already existed from story 017/016-era code; this story routed it through the
same `_offers_retreat()` helper the new payload uses, rather than leaving two
copies of the same condition to drift.

**Items owed**: none for this story. Camp-availability and region-default
rules remain story 020/021's concern, as scoped.

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`, `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing
**Deviations**: None. `choose_retreat()`'s reject-when-not-offered guard and `report_battle_outcome()`'s DEFEAT case now route through the same `_offers_retreat()` helper, so the offer and the rejection can never disagree — a correction within this story's own scope, not a deviation from it.
**Test Evidence**: `tests/unit/game_state/game_state_retreat_offer_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
