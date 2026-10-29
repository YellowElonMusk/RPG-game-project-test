# Story 052: An off-screen Victory plays the off-screen sting and the payoff card together

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`transition_finished` timing)
**ADR Decision Summary**: A marker outside the camera footprint is removed off-screen in `on_thawed`; because contact can happen anywhere along a chase, that marker may still be off-screen at the reveal, so the win is announced both heard (the off-screen sting) and seen (a payoff-card line) on the same frame.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Audio-sting timing rides the same `transition_finished` contract as stories 047 and 050; HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: A marker outside the footprint is removed off-screen in `on_thawed`; its visual twin is a payoff-card line on `transition_finished` — ADR-0012 §5, GDD rule 9
- Forbidden: Never liberate an off-screen marker silently with no card line — the GDD explicitly forbids an audio-only result
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-21d [L] (R9, R7a)** GIVEN a Victory whose linked marker is outside the footprint, THEN on `transition_finished` the audio spy records the off-screen sting **and** the payoff card shows a "Street cleared" line on the same frame.

---

## Implementation Notes

*Derived from GDD rule 9 ("Local liberation", "A marker outside the camera footprint") and rule 7a ("Payoff card"):*

- Fixture a symbol whose linked clutter marker lies outside the camera footprint at Victory time (contact can happen anywhere along a chase, so this is a normal case, not an edge case); drive the Victory through `on_thawed` (marker joins the liberated set, cells freed) then `transition_finished`.
- Assert an audio spy records the off-screen liberation sting on the `transition_finished` frame.
- Assert the payoff card shows a liberation line (the GDD's own example: "Street cleared: Rue des Tampons") on that **same** frame — not a frame later, not conditional on the audio spy's result.
- Contrast with an on-screen marker (inside the footprint) in a second fixture: assert it stays visible until `transition_finished`, then plays its on-screen removal instead of the off-screen sting, finishing within `liberation_duration_s` — this story's AC only requires the off-screen branch, but the contrast fixture guards against the two paths being accidentally merged.

---

## Out of Scope

- `story-050-first-victory-grants-payoff.md`: the payoff-granting mechanism this story's card line depends on.
- `story-043-victory-respawn-policy.md`: symbol resolution itself.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/world_state.gd`
- `tests/unit/overworld/overworld_mode_offscreen_liberation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_offscreen_liberation_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-043-victory-respawn-policy.md`, `story-050-first-victory-grants-payoff.md`
- Unlocks: `story-057-new-game-permits-mandatory-timing.md` (AC-23d, the liberation registry integration)
