# Story 058: Active markers follow the marker_activation formula's slots

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `OverworldMode._ready()` activates markers sorted by `(min_stage, marker order)` against each kind's stage cap, so a newly eligible marker never displaces one already holding a slot.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure GDScript, computed once per map load; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: `OverworldMode._ready()` builds only per-visit state, in order: `MapData` + stage + liberation → scene by ID convention → bake → markers (`min_stage`, caps sorted by `(min_stage, marker order)`) and blockers → ... → `stage.profile_id` before tree — source: ADR-0012 §4
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-24 [L] (`marker_activation`)** Using the P1–P6 example and a randomized-order fixture, the active markers equal the formula, sorted by (`min_stage`, marker order). At stage 2, P1, P4, P6 and P2 hold the slots. Liberating P2 shows 3 posters, and P5 stays hidden. At stage 3 with an equal cap of 4, the same four keep their slots.

---

## Implementation Notes

*Derived from the GDD `marker_activation` Formulas section:*

`E_k = [m of kind k with m.min_stage ≤ stage], sorted by (min_stage, marker order); slot(m) = index_in(E_k, m) < cap(faction, stage, k); visible(m) = slot(m) ∧ m ∉ liberated(map) ∧ ¬region_liberated(map)`

- Sorting by `min_stage` first means markers that become candidates at a new stage always join the end of the list, so they never displace a marker that already held a slot.
- Decree gags are their own kind and are not capped (rule 8; story-056).
- A liberated marker **keeps its slot** — liberating it never pulls in a replacement, so the street visibly empties (Output Range).
- Caps never fall as the stage rises (I13), so a marker visible at one stage keeps its slot at the next, even at an equal cap (the stage-3 example with cap 4).
- Marker order is a total order (scene child order), so ties cannot happen.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-059-liberated-set-persists-across-respawn-and-stage: the `liberated(map)` set's own persistence (AC-25)

---

## Files

- `src/overworld/overworld_mode.gd` (`_ready` step 4: activate markers)
- `tests/unit/overworld/marker_activation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/marker_activation_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-053-occupation-stage-formula.md` (the `occupation_stage` formula)
- Unlocks: `production/epics/overworld-exploration-encounters/story-059-liberated-set-persists-across-respawn-and-stage.md`
