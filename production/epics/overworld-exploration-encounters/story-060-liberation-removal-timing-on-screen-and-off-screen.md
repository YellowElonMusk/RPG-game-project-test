# Story 060: On-screen liberation removal times to transition_finished; off-screen to on_thawed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: An off-screen linked marker is removed and its cells freed in `on_thawed`, under the wipe; an on-screen marker stays visible until `transition_finished`, then plays its removal, finishing within `liberation_duration_s`, with cells freed at the end.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API here; risk comes from citing ADR-0002's two-step thaw (`on_thawed` / `transition_finished`), whose own Engine Compatibility row is HIGH.

**Control Manifest Rules (this layer)**:
- Required: Two-step thaw — all state changes in `on_thawed` under the wipe; on `transition_finished`, grace and Noticing/Chasing → Returning, but on-screen liberation and the payoff card only when `pending_thaw` is set — source: ADR-0012 §5
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-26a [L] (R9, R7)** On the mode clock, an on-screen marker's removal has not started at `transition_finished − dt`, has started at `transition_finished + dt`, and is complete, with its cells freed, at `transition_finished + liberation_duration_s + dt`. An off-screen marker is removed in `on_thawed`, and its cells are freed then. A Dialogue due from the same battle opens after the on-screen removal ends.

---

## Implementation Notes

*Derived from GDD rule 9 ("Timing") and rule 14 (story-flag ordering):*

- A marker **outside** the camera footprint is removed under the wipe, in `on_thawed`, so it is already clear when the player walks to it; its blocked cells free at once.
- A marker **inside** the footprint stays visible until `transition_finished` (rule 7, step 2), then plays its removal on screen, finishing within `liberation_duration_s`; its cells free at the end of that removal.
- Rule 14: story Dialogue opens once the on-screen removal has finished, or at once if there is none — so this story's timing gates when a same-battle Dialogue is allowed to open.
- Test on the injectable mode clock per the harness's timing rule: assert at `transition_finished − dt` / `+ dt`, and again at `transition_finished + liberation_duration_s + dt`, never on a threshold frame.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-061-liberation-screenshots-poster-queue-checkpoint: the visual capture of this timing (AC-26b)
- story-062-liberation-grumble-share-and-deflated-clerk: the reaction content that plays once removal completes (AC-26d)

---

## Files

- `src/overworld/overworld_mode.gd` (`on_thawed` / `transition_finished` liberation sequencing, `pending_thaw` flag)
- `tests/unit/overworld/liberation_removal_timing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/liberation_removal_timing_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-059-liberated-set-persists-across-respawn-and-stage.md`, `story-047-encounter-grace-starts-on-reveal.md`, `story-048-timers-freeze-under-overlays.md` (the two-step thaw)
- Unlocks: `production/epics/overworld-exploration-encounters/story-061-liberation-screenshots-poster-queue-checkpoint.md`
