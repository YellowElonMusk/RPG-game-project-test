# Story 115: Playtest confirms players can both bypass and engage Clerks

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-004 — the symbol sub-state machine that makes both chasing and give-up/bypass possible — is the closest match; no TR names playtesting itself.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's `SymbolBrain` sub-state machine (Patrol/Noticing/Chasing/Returning) and GDD rule 12 (safe zones, bypass lanes, pressure) together are what this playtest is validating actually plays as "avoidable but real."
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No engine surface — this is a human playtest, not an automated test.

**Control Manifest Rules (this layer)**:
- Required: none directly (this story measures emergent play, not a coded rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-47 [PT]** A playtest report with at least 5 first-time players on the Paris chapter. For each symbol that comes within `see_m`, the facilitator logs it as *engaged* or *bypassed*. Fixed survey wording asks Q3, "I was pulled into a fight I didn't choose", and Q4, "Fights felt like grind", each answered Yes or No. **Goal:** every player has at least 1 bypass and at least 1 engaged street Clerk, and the facilitator logs which payoff types each engaged Clerk carried. At most 1 player answers Yes to Q3 or Q4. (The rule-comprehension item is not here: it is BLOCKING, in AC-50b.)

---

## Implementation Notes

*Derived from the test plan's O-09 procedure:*

- Players: at least 5 first-time players who have not seen the game, no coaching. Session: New Game through the Paris chapter, recorded (screen + audio, timestamped).
- Facilitator log: for each symbol that came within `see_m` of the leader, *engaged* or *bypassed*, and for each engaged Clerk, which payoff types it carried. The OW-T04 logger is proposed but not adopted (test plan Findings item 5); until it ships, the facilitator logs by eye and the report states that explicitly.
- Survey, read verbatim, each Yes/No: Q3 "I was pulled into a fight I didn't choose" and Q4 "Fights felt like grind" are fixed wording and may not be paraphrased (both feed this AC). Q1 and Q2 belong to story 116.
- Goal (ADVISORY): every player has ≥ 1 bypass and ≥ 1 engaged street Clerk; at most 1 player answers Yes to Q3 **or** Q4, read as one player across both questions.
- Report to `production/qa/evidence/playtest-overworld-[date].md`. This AC is ADVISORY — a playtest goal recorded as evidence, not a gate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 116 (`story-116-paris-walk-share-playtest.md`): the walk-share-of-chapter-time measurement from the same playtest sessions.
- Story 120 (`story-120-faction-clue-narrative-signoff-and-comprehension.md`): the BLOCKING comprehension check asked during the same playtest, before the first Bureaucratia battle.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No source files — a human playtest report.
- `production/qa/evidence/playtest-overworld-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: playtest report in `production/qa/evidence/playtest-overworld-[date].md`. ADVISORY.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: a playable Paris chapter build (critical-path stories across this epic, outside this writer's range), `story-120-faction-clue-narrative-signoff-and-comprehension.md` (shares the same playtest session for its BLOCKING comprehension item)
- Unlocks: None
