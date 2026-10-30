# Story 126: Every overworld SFX event has its visual twin on the same frame

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

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

- [x] **AC-53 [L] (Visual/Audio, twins)** For every overworld SFX event in the audio table, the event spy records the sound together with its visual twin on the same frame (the payoff card counts for the off-screen sting).

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

- `src/overworld/overworld_sfx.gd` (new: the six audio-table event ids)
- `src/overworld/overworld_mode.gd` (additive: `sfx_cue` signal and its six emission points)
- `tests/unit/overworld/audio_visual_twin_test.gd` (new: event spy over the audio table's six rows)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/audio_visual_twin_test.gd` — must exist and pass.

**Status**: [x] Created and passing (9/9 in `audio_visual_twin_test.gd`)

---

## Dependencies

- Depends on: `story-059-liberated-set-persists-across-respawn-and-stage.md` (AC-25, liberation visuals), Audio Manager (no epic yet, named as a dependency)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30 (awaiting /story-done)
**Criteria**: 1/1 (AC-53) covered by automated test.

- No Audio Manager or SFX triggers existed, so this story adds the minimal seam, not an Audio Manager: `OverworldMode.sfx_cue(event: StringName, subject: String)`, with the six ids in `OverworldSfx`. Nothing listens yet (`TODO(audio-manager)`).
- Emission points: Notice and Chase in `step_frame` on the brain's sub-state change; Stun on the reveal (`transition_finished`) for a symbol Fled stunned, not under the wipe; on-screen Liberation in `_start_removals`; the off-screen sting in `_show_payoff_card` with the "Street cleared" line; Checkpoint denial when the failure line's Dialogue opens.
- **Deviation / limitation**: visual twins are asserted on the model state the presentation reads (sub-state, `is_removing`, payoff card, Dialogue line); no view code draws the poses, slips or DENIED stamp yet (story 125 and art). `pending_thaw` stands for "scene under the wipe".
- The test spy filters by subject: the Paris segment's own off-screen markers (`poster_permit_queue`) also sting on the East Clerk's Victory.
- Status synced 2026-10-30 from commit df9a914.
