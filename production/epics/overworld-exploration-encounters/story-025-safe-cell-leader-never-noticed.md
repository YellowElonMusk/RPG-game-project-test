# Story 025: A leader standing in a SAFE cell is never noticed, even inside the front radius

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The notice test's second cheap check rejects the leader outright when it stands in a `SAFE` cell, regardless of distance or reachability — `SAFE` cells are baked conservatively around EntryPoints, MapExits, CampSpots and return markers, and symbols can never enter them at all.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure cell-flag lookup against a fixture `WalkGrid`; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "`SAFE` cells are not symbol-legal (rule 0), so chase and push stop at the edge. A leader in a safe zone cannot be noticed or touched" — source: GDD rule 12, ADR-0012 §2 (`is_symbol_legal`)
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, notice with cheap checks first...)" — source: ADR-0012 §5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-9f [L] (R5, SAFE)** GIVEN the leader in a `SAFE` cell inside a patrolling symbol's front radius with a reachable path, THEN no notice on any frame over 10 s.

---

## Implementation Notes

*Derived from ADR-0012 §2/§5 and GDD rule 5's notice test, check 2, plus rule 12's safe-zone guarantee:*

GDD rule 5's notice test, check 2: "the leader is not in a `SAFE` cell."
Rule 12: "Symbols never enter safe zones... A leader in a safe zone cannot be
noticed or touched, and a chase on them gives up." This AC isolates check 2
by deliberately satisfying checks 1 and 4 (front radius, reachable path) so
only the `SAFE` flag can be responsible for the suppression.

- Fixture: a `SAFE`-tagged cell inside the symbol's front half-plane radius, with a genuinely reachable path (within `notice_path_cap_m`) from the symbol to that cell — every other check would pass.
- Step for 10 s of simulated time across multiple frames (covering both `dt = 1/60 s` and `dt_max`) and assert the notice test never fires.
- Build the fixture `WalkGrid` with the `SAFE` bit set directly on the target cell (`is_symbol_legal()` must return false for it); this story does not exercise the conservative bake-from-`TileMapLayer` pipeline itself.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 022: the front/rear radius check (check 1).
- Story 023: the bounded-search path-cap check (check 4).
- Story 024: sub-state and grace gating (a different, earlier short-circuit).
- AC-11 (outside this batch): a chase that is already underway when the leader reaches a `SAFE` cell (give-up, not notice-suppression).

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/symbol_brain_safe_cell_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_safe_cell_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: None
