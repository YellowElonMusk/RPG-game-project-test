# Story 034: Each symbol's chase target offsets sideways by its own marker index

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
**ADR Decision Summary**: The chase target is the symbol-legal cell nearest the leader, offset sideways by `(marker index mod 3 − 1) · body_radius` perpendicular to that symbol's own symbol-to-leader vector, so Clerks chasing together stay visibly distinct.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure vector arithmetic; no engine-specific risk beyond the already-probed symbol-legal cell lookup.

**Control Manifest Rules (this layer)**:
- Required: Chase target computed per `SymbolBrain`, offset by that symbol's own symbol-to-leader vector — ADR-0012 §5, GDD rule 5 ("Chase target")
- Forbidden: Never drop the offset silently when it lands off a symbol-legal cell — fall back to the un-offset nearest cell instead (GDD rule 5)
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-10d [L] (R5, chase target)** GIVEN a leader standing still at an off-centre point of a cell, THEN a chasing symbol reaches contact within `(path_dist₀ / v_chase) + 2·dt`. GIVEN symbols chasing with marker indices i = 0, 1, 2, THEN each target's offset from its nearest-cell point equals `|(i mod 3) − 1| · body_radius`, perpendicular to **that symbol's own** symbol-to-leader vector, and the offset is dropped when the offset point is not symbol-legal. Ties for the nearest cell go to the lowest cell index.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 ("Chase target"):*

The offset keeps two or three Clerks chasing the same leader from stacking
visually on the exact same cell.

- For the contact-timing half of the AC: place the leader stationary off-centre in a cell, and assert the chasing symbol makes contact within `(path_dist₀ / v_chase) + 2·dt` — a tight bound that catches an off-by-one-frame or an extra repath delay.
- For the offset half: build three symbols with marker indices 0, 1, 2 chasing the same leader, and assert each one's chase target's distance from the nearest-cell point equals `|(i mod 3) − 1| · body_radius` — i.e. 1, 0 and 1 `body_radius` respectively — each measured **perpendicular to that symbol's own** symbol-to-leader vector, not a shared axis.
- When the offset point is not on a symbol-legal cell, assert the brain falls back to the plain nearest-cell target (GDD rule 5 says the offset is "dropped", not clamped or searched for an alternative).
- Ties for the nearest cell resolve to the **lowest cell index** — construct a fixture where two cells are equidistant to prove the tie-break, not just document it.

---

## Out of Scope

- `story-031-chase-speed-and-repath-throttle.md`: chase speed and repath cadence.
- `story-035-final-approach-legality.md`: when the symbol steers straight at the offset point versus follows the path.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_chase_target_offset_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_chase_target_offset_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-031-chase-speed-and-repath-throttle.md`
- Unlocks: `story-035-final-approach-legality.md`
