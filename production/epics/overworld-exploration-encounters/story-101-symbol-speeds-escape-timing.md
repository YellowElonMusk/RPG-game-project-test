# Story 101: A chase started at minimum contact distance gives up within one frame of `t_escape`

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `SymbolBrain`'s give-up test uses `path_dist` against `symbol_giveup_m`, and the open-ground worst case is bounded by the `symbol_speeds` formula's `t_escape`, itself bounded by invariant I2.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure `SymbolBrain` timing logic; no engine surface.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, … the give-up test, the resume point …)" — source: ADR-0012 §5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-40b [L] (`symbol_speeds`)** GIVEN open ground and a chase starting at `d0` = 2·`body_radius` + 0.05 m (so no contact on the first frame), with the leader walking straight away at `walk_speed`, THEN the symbol is Chasing at `t_escape(d0) − dt` and Returning at `t_escape(d0) + dt`.

---

## Implementation Notes

*Derived from GDD Formulas ("symbol_speeds") and rule 5 ("Give-up test"):*

- `t_escape(d0) = max(0, symbol_giveup_m − d0) / (walk_speed − v_chase) + giveup_s`, with `v_chase = f_chase · walk_speed`.
- Open ground (no walls to path around — the open-ground bound is the worst case per the Formulas' Output Range note); chase starts at `d0 = 2·body_radius + 0.05` m, guaranteeing no contact on the first frame; the leader walks straight away at `walk_speed` for the whole run.
- Per the timing rule, choose `dt` so `t_escape(d0) / dt` is not a whole number. Assert the symbol is still **Chasing** at `t_escape(d0) − dt` and has reached **Returning** at `t_escape(d0) + dt`.
- Use the GDD's own worked example to cross-check the formula, not as the test's literal fixture: `walk_speed` 3.5 m/s, `symbol_giveup_m` 6.5 m, worst case (`d0` = 0.6 m) gives `t_escape` = 9.93 s.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The swept-contact test this story's `d0` is chosen to avoid triggering on frame one (story 100).
- `path_dist`'s own upper-bound proof through a non-open-ground corridor (story 102).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_escape_timing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_escape_timing_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-100-swept-contact-at-every-approach-angle.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-102-path-dist-upper-bound-through-a-u-corridor.md`

## Completion Notes (2026-10-30)

The test first failed: on open ground the symbol gave up 1.4 s early (crossing at 5.7 s instead of 8.36 s). Three `SymbolBrain` fixes, each seen to move the result:

1. **The route ends at the chase target, not its cell's centre.** The GDD defines the chase target as the leader's own point when its cell is legal. The centre could sit up to a cell past the leader, inflating `path_dist` (`_install_route` now takes the end point).
2. **Waypoints the final approach has passed drop out** while the next one is in a straight legal line, so `arc(c_S → w_last)` stays a tight real route instead of zigzagging back.
3. **No idling at a route's end.** A symbol that has run out of route repaths at once (still budgeted) instead of waiting out `repath_s`. A route that runs out mid-frame spends the rest of the step on the chase target when the line is clear, but not when A* found no route: the empty-path hold is unchanged.

- `path_dist` stays an upper bound (each part is still a real route segment). On open ground it now equals the true distance, and the chase ends within one frame of `t_escape(d0)` at dt 1/60, 0.017 and 0.05.
- The test uses `marker_index` 1. The other markers' sideways chase-target offset (`body_radius`, which spreads multiple chasers) adds a constant gap that the open-ground formula does not model; give-up then comes up to 0.43 s earlier, which is still within the bound.
- All 121 symbol and chase tests still pass.
