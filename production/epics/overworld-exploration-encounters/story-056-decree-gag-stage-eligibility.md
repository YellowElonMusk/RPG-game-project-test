# Story 056: Decree gags stay eligible and exempt from stage caps

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`, `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: Decree gags are an `Interactable` kind raised and retired by the stage rule but never counted against a kind's cap, never a route-blocker, and never a `probe()` target once region liberation clears them.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure GDScript over `OverworldConfig` and the `occupation_stage`/`marker_activation` records; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: Interaction is one `probe()` (nearest eligible target; ties NPC → CampSpot → Static symbol → Interactable) that drives both the prompt and `confirm` — source: ADR-0012 §6, GDD rule 3 / AC-7a
- Forbidden: Never store a scene path on `MapData` — breaks Content Data Rule 3 — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 on the GTX 1080-class PC and the Steam Deck — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-23c [L] (R8)** A decree gag is active only at or above its new stage, is not counted against any cap, never blocks a cell, is eligible for `confirm`, and is inactive once `region_liberation_flag` is set.

---

## Implementation Notes

*Derived from GDD rule 8 and the `marker_activation` Formulas section:*

- A decree gag is active at and above its new stage (the decree stays in force) and is exempt from the stage caps and from the "no faction clutter in a safe zone" rule (rule 8, rule 12/Visual-Audio).
- It never blocks a route, and is always eligible for `confirm`, which shows its text (rule 3, rule 16).
- The `marker_activation` formula treats decree gags as their own kind, outside `cap(faction, stage, k)` entirely — they are never counted in `E_k` for any capped kind.
- It is removed, like all clutter, by region liberation (rule 9): once `region_liberation_flag` is set, it is treated as liberated and drops out of `probe()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-055-paris-map-stage-and-decree-registry-rules: CI placement of decree gags at every usable EntryPoint (AC-23b)
- story-058-marker-activation-slots-by-stage-and-cap: capped-kind slotting (AC-24)

---

## Files

- `src/overworld/markers/decree_gag.gd`
- `src/overworld/overworld_mode.gd` (`probe()` eligibility branch)
- `tests/unit/overworld/decree_gag_stage_eligibility_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/decree_gag_stage_eligibility_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-053-occupation-stage-formula.md` (the `occupation_stage` formula)
- Unlocks: `production/epics/overworld-exploration-encounters/story-057-new-game-permits-mandatory-timing.md`

## Completion Notes (2026-10-30)

- Decree gags are `GagInteractable`s with `decree_stage` (active at and above) or `decree_first_sight` (a symbol ID). Stage caps do not exist yet (story 058), so exemption from them is trivially true.
- Content: the segment decree at both EntryPoints (stage 2) and the dungeon camp first-sight decree announcing the Permit Counter.
