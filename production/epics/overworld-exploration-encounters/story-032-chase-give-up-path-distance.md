# Story 032: A chase gives up only after path_dist exceeds symbol_giveup_m for giveup_s

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
**ADR Decision Summary**: `SymbolBrain.path_dist()` computes a true upper bound on the leader's path distance from the stored route; the give-up test passes only once that bound exceeds `symbol_giveup_m` continuously for `giveup_s`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No engine-specific risk; `path_dist` is pure arithmetic over a stored path, not a live A* query.

**Control Manifest Rules (this layer)**:
- Required: Symbol AI's give-up test uses `path_dist`, a real-route upper bound, never straight-line distance — ADR-0012 §5, GDD rule 5
- Forbidden: Never use straight-line distance for the give-up test — a switchback must not hold a chase open forever, nor end it early
- Guardrail: n/a (no per-frame cost beyond the existing repath budget)

---

## Acceptance Criteria

- [ ] **AC-10b [L] (R5, give-up)** GIVEN a chase in a switchback fixture where the straight-line distance stays under `symbol_giveup_m` but `path_dist` exceeds it from time `t₀`, with `dt` chosen so that `giveup_s/dt` is not whole, THEN the symbol is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`. The test's `path_dist` is recomputed from the stored path each frame, per rule 5.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 ("Path distance", "Give-up test"):*

`path_dist(t) = arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)` joins
three real route segments, so it is always at least the shortest route — it
can only make give-up earlier than straight-line distance would, never later.

- Build the switchback fixture so straight-line distance from symbol to leader stays well under `symbol_giveup_m` throughout, while the walked-route `path_dist` crosses it at `t₀` — this is the whole point of the AC: a naive straight-line give-up test would never fire here.
- Follow the GDD's timing rule: pick `dt` so `giveup_s / dt` is not a whole number, and assert Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`.
- Recompute `path_dist` from the stored path on **every** frame of the window, not once at `t₀` — the give-up timer only holds if the bound stays past `symbol_giveup_m` "without a break" (GDD rule 5).
- The give-up test also passes on a `SAFE`-cell leader or an empty path with nothing pending (GDD rule 5) — this story covers the `path_dist` branch only; the empty-path and SAFE branches belong to story 036 (AC-11) and story 037 (AC-12).

---

## Out of Scope

- `story-033-returning-to-resume-point.md`: what happens after give-up.
- `story-036-chase-gives-up-at-safe-zone.md`: the SAFE-cell give-up branch.
- `story-037-chase-pathing-edge-cases.md`: the empty-path give-up branch.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_giveup_path_dist_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_giveup_path_dist_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-031-chase-speed-and-repath-throttle.md`
- Unlocks: `story-033-returning-to-resume-point.md`, `story-036-chase-gives-up-at-safe-zone.md`, `story-037-chase-pathing-edge-cases.md`
