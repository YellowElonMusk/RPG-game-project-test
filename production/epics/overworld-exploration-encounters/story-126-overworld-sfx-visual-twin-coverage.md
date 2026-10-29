# Story 126: Every overworld SFX event has its visual twin on the same frame

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-017 — Presentation — is the closest match; no TR names audio explicitly.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: ADR-0012 defines the events (notice, chase, stun, liberation, checkpoint denial) this accessibility guarantee covers; ADR-0002 owns the `on_thawed`/`transition_finished` sequencing the off-screen sting and payoff card twin depend on.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — an event-spy assertion over existing Audio Manager triggers and their visual counterparts.

**Control Manifest Rules (this layer)**:
- Required: none directly (an accessibility/audio-twin assertion, not a coded ADR-0012 rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-53 [L] (Visual/Audio, twins)** For every overworld SFX event in the audio table, the event spy records the sound together with its visual twin on the same frame (the payoff card counts for the off-screen sting).

---

## Implementation Notes

*Derived from GDD Visual/Audio Requirements § Audio direction:*

Every sound has a visual twin ([A11Y] preamble). The audio table pairs each event:

| Event | Sound mood | Visual twin |
|---|---|---|
| Notice | Pen-click "ahem" | "!" slip + notice pose |
| Chase | Hurried footsteps, paper rustle | Chase pose + paper trail |
| Stun | Dazed paper flutter | Orbiting slips |
| Liberation | Paper tear, scattered individual reactions | Clutter removal |
| Off-screen liberation | A short paper-tear sting | The payoff card's "Street cleared" line (rule 7a) |
| Checkpoint denial | Stamp thunk | DENIED stamp + redirect |

- Use an event spy (per the test harness's stubbed-neighbour convention) that records every Audio Manager trigger the overworld fires, and the frame each paired visual element becomes visible.
- Pass when, for every row in the table, the sound and its visual twin are recorded on the **same frame**.
- The off-screen liberation row is the one indirection: its "visual twin" is not an on-screen effect but the payoff card's "Street cleared" line — the spy must accept the payoff card's appearance frame as satisfying this row, exactly as the AC states.
- This story does not author new sounds or visuals; the Audio Manager owns layers, triggers and mix (Visual/Audio Requirements preamble) — this story only asserts the pairing contract.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 125 (`story-125-event-feedback-screenshot-set.md`): the retained screenshots of each visual cue itself.
- The Audio Manager's own mix/trigger implementation — it has no epic yet in this writer's range and is named as a dependency.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/unit/overworld/audio_visual_twin_test.gd` (event spy over the audio table's six rows)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/audio_visual_twin_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-059-liberated-set-persists-across-respawn-and-stage.md` (AC-25, liberation visuals), Audio Manager (no epic yet, named as a dependency)
- Unlocks: None
