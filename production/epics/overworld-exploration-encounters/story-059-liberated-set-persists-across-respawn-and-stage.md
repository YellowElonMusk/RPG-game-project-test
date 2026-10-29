# Story 059: Liberated marker IDs persist across respawn, stage raise and save/load

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

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `WorldState.liberate(map_id, marker_ids)` is the single write path for a map's liberated set, called from `on_thawed`, and the set is per-map saved state that a Clerk respawn or a later stage raise never clears.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API in this path; risk comes from citing ADR-0002's two-step thaw (`on_thawed`), whose own Engine Compatibility row is HIGH.

**Control Manifest Rules (this layer)**:
- Required: `WorldState` is the single owner of state that outlives a visit (resolved symbols, opened interactables, liberated markers, `stage_stored`, payoffs) — source: ADR-0012 §4
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld memory: ~1 byte per walk cell plus a 4-byte component label; the detached Overworld stays resident during battles — source: ADR-0012 Performance

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-25 [L] (R9, Edge Cases)** GIVEN Victory over a linked Clerk, THEN its marker IDs join the map's liberated set in `on_thawed`. When that Clerk respawns, and after a stage raise, those markers stay hidden. Beating the respawned Clerk adds nothing. The liberated set survives save and load.

---

## Implementation Notes

*Derived from GDD rule 9 ("Timing", "Permanence") and the Edge Cases list:*

- Rule 9, Timing: when the symbol is beaten, or the flag is set, the marker joins the map's liberated set in `on_thawed` (rule 7, step 1).
- Rule 9, Permanence: a liberated marker stays liberated when its Clerk respawns, and when a later stage raise reactivates its area. The Clerk itself still respawns per its `respawn` policy, so a cleared street still has a patrol to avoid or fight.
- Edge case: "If a liberated marker's symbol respawns: the marker stays liberated. Beating the respawned Clerk again liberates nothing new and grants no payoff" (rule 7a).
- Rule 9, Saving: the liberated set per map is saved in world state (`WorldState` field list, ADR-0012 §4).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-060-liberation-removal-timing-on-screen-and-off-screen: the on-screen/off-screen removal animation timing (AC-26a)

---

## Files

- `src/overworld/world_state.gd` (`liberate`, per-map liberated set)
- `src/overworld/overworld_mode.gd` (`on_thawed` call site)
- `tests/unit/overworld/liberated_set_persistence_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/liberated_set_persistence_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-047-encounter-grace-starts-on-reveal.md`, `story-048-timers-freeze-under-overlays.md` (the two-step thaw, AC-20a/AC-20b), `story-058-marker-activation-slots-by-stage-and-cap.md` (`liberated(map)` feeds `visible(m)`)
- Unlocks: `production/epics/overworld-exploration-encounters/story-060-liberation-removal-timing-on-screen-and-off-screen.md`
