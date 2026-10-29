# Story 101: A chase started at minimum contact distance gives up within one frame of `t_escape`

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
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

- [ ] **AC-40b [L] (`symbol_speeds`)** GIVEN open ground and a chase starting at `d0` = 2·`body_radius` + 0.05 m (so no contact on the first frame), with the leader walking straight away at `walk_speed`, THEN the symbol is Chasing at `t_escape(d0) − dt` and Returning at `t_escape(d0) + dt`.

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
- `tests/unit/overworld/symbol_speeds_escape_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_speeds_escape_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-100-swept-contact-at-every-approach-angle.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-102-path-dist-upper-bound-through-a-u-corridor.md`
