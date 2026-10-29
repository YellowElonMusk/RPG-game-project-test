# Story 116: Measure the share of chapter time spent walking against the budget

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-012 — map/leg structure, which the walk budget is computed from — is the closest match; no TR names playtesting itself.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's map/leg records are what `L_crit`/`L_bypass` and the `chapter_walk_budget` formula are computed from; this story checks that real play lands inside the budget those formulas predict.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No engine surface — a human playtest measurement.

**Control Manifest Rules (this layer)**:
- Required: none directly.
- Guardrail: none (this is the real-play check against the `chapter_walk_budget` level-review budget, not a runtime guardrail).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-48 [PT]** From timestamped session recordings in the same playtest, record the share of chapter time spent moving on the overworld and compare it with `walk_share_max`. A survey item asks whether walking felt slow. The result feeds OQ-9 (Fast Walk).

---

## Implementation Notes

*Derived from the test plan's O-09 procedure and the GDD's `chapter_walk_budget` formula:*

- Source data: the same timestamped session recordings as story 115's playtest (at least 5 first-time players, Paris chapter, New Game through the chapter).
- Walk share = overworld moving time ÷ chapter time, computed from the recordings (or from the OW-T04 logger if it is adopted later).
- Compare per player against `walk_share_max` (the GDD's `chapter_walk_budget` tuning knob) and report the result per player, not just an average.
- Survey item Q1, read verbatim: "Walking between places felt slow." (Yes/No). Information only, feeds OQ-9 (Fast Walk).
- This AC is ADVISORY: information for the OQ-9 open question, not a pass/fail gate. There is no pass threshold stated — report the measured shares and the survey answers.
- Report to the same file as story 115: `production/qa/evidence/playtest-overworld-[date].md`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 115 (`story-115-paris-playtest-engagement-report.md`): the engaged/bypassed log and the Q3/Q4 survey items from the same sessions.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No source files — a human playtest measurement.
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

- Depends on: `production/epics/overworld-exploration-encounters/story-115-paris-playtest-engagement-report.md` (same playtest sessions)
- Unlocks: None
