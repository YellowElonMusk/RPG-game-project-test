# Story 033: Returning walks by A* to the resume point, then resumes Patrol deaf

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: Returning walks at `v_patrol` by `AStarGrid2D` over symbol-legal cells to the stored resume point, then resumes Patrol in its earlier direction; Returning is deaf and intangible throughout, and for `renotice_cooldown_s` after rejoining.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Returning's A* queries share the same probed `AStarGrid2D` configuration and query budget as Chasing; no distinct engine risk.

**Control Manifest Rules (this layer)**:
- Required: Returning paths share `repath_per_frame_max` through the round-robin cursor, inside the query budget — ADR-0012 §5
- Forbidden: Never let a Returning symbol run the notice test or count in contact — GDD rule 5, "deaf and intangible"
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-10c [L] (R5, Returning)** GIVEN give-up, THEN the symbol walks by A* at `v_patrol` to its stored resume point, then resumes Patrol in its earlier direction. It notices nothing until `renotice_cooldown_s` after rejoining (asserted at `− dt` and `+ dt`), and no contact occurs while it is Returning, even when it walks through the leader.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 (Returning row):*

Returning is the sub-state the GDD calls "deaf and intangible": no notice
test, no contact, whatever the leader does.

- After give-up, assert the symbol's path target is the **stored resume point** (the Patrol position recorded at the original contact or patrol departure, GDD rule 5 "Contact"), walked at `v_patrol` by A*.
- On reaching the resume point, assert Patrol resumes **in the direction the symbol was going before it left** — not reset to the path's start.
- Apply the GDD timing rule to `renotice_cooldown_s`: assert no notice at `renotice_cooldown_s − dt` after rejoining Patrol, and notice becomes possible at `renotice_cooldown_s + dt`.
- Walk the leader directly through the Returning symbol's cell during the walk and assert no contact fires — contact only counts in Patrol, Noticing, Chasing and `contact_or_confirm` Static (GDD rule 5, "Contact").

---

## Out of Scope

- `story-032-chase-give-up-path-distance.md`: when give-up triggers Returning.
- `story-037-chase-pathing-edge-cases.md`: the unreachable-resume-point branch.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_returning_resume_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_returning_resume_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-032-chase-give-up-path-distance.md`
- Unlocks: `story-037-chase-pathing-edge-cases.md`, `story-045-stunned-symbol-grants-no-encounter.md`
