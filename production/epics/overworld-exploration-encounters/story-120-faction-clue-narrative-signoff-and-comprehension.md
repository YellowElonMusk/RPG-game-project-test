# Story 120: The Paris clue is legible on the Deck and the comprehension check passes

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-018 — player-facing overworld text — is the closest match; no TR names the narrative sign-off process itself.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012 commits poster/decree text to `LocText`, shown verbatim on `confirm`; GDD rules 16 and 18 add the comprehension check and the sign-off record this story's evidence is built from.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No engine surface — a narrative sign-off record plus a retained Steam Deck capture and a playtest comprehension score.

**Control Manifest Rules (this layer)**:
- Required: none directly (this is a content/process gate, not a coded rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-50b [N] (R16, R18)** The narrative sign-off record has an entry for the Paris clue with: the on-screen text legible without interaction, shown by a retained Steam Deck capture at 1280×800; and the comprehension check passed. That check is run in the AC-47 playtest **before the player's first Bureaucratia battle**, with the fixed wording in the test plan, and passes when at least 60% of the players (at least 5) state that the enemy takes no damage until it is Approved. This one playtest item is BLOCKING through this AC.

---

## Implementation Notes

*Derived from GDD rules 16 and 18, and the test plan's O-09 procedure:*

- Legibility: the clue poster's painted text must be legible **without interacting** on the Steam Deck's 7" screen (rule 16 "Faction-rule clue"). Evidence: a retained Steam Deck capture at 1280×800 (`CP-SEG-S2-DECK` framed on the clue, test plan O-06/O-09).
- Comprehension check (rule 18 tick (e)): run during the same AC-47 playtest, **before the player's first Bureaucratia battle**. The OW-T04 hook is proposed but not adopted; until it ships, the fallback is to hold at the first Bureaucratia battle's first command prompt, before any action resolves — a departure the narrative and QA owners must accept (test plan Findings item 6).
- Fixed wording, read verbatim once, no follow-up hint: *"Before this fight: from what you've seen so far, is there anything special about how these clerks can be hurt?"*
- Scoring: the facilitator and one independent second reviewer each score the answer against — *the answer states, in any words, that the enemy takes no damage (or ignores/does not process injuries) until it is Approved (stamped)*. Both must score it correct; a disagreement scores incorrect. A player who never reached the clue counts in the denominator as incorrect.
- Pass: correct ≥ 60% of players, with at least 5 players. This single item is BLOCKING even though the rest of AC-47/48 are ADVISORY.
- Record the result in `design/gdd/reviews/overworld-narrative-signoff.md` with the retained Steam Deck capture.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 115 (`story-115-paris-playtest-engagement-report.md`): the engaged/bypassed log and Q3/Q4 survey from the same playtest sessions.
- Story 121 (`story-121-narrative-guardrail-signoff-checklist.md`): the full narrative sign-off checklist across every other content set.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No source files — a playtest comprehension score plus a sign-off record entry.
- `design/gdd/reviews/overworld-narrative-signoff.md`
- `production/qa/evidence/playtest-overworld-[date].md` (the comprehension check runs inside the same session)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: narrative sign-off entry in `design/gdd/reviews/overworld-narrative-signoff.md`. BLOCKING (the GDD makes this one playtest item BLOCKING despite the rest of AC-47/48 being ADVISORY).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-119-faction-clue-placement-ordering.md`, `production/epics/overworld-exploration-encounters/story-115-paris-playtest-engagement-report.md` (same playtest session)
- Unlocks: None
