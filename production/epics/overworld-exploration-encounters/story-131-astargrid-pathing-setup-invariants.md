# Story 131: AStarGrid2D setup stays frozen after bake, and sprite frames never drift from ow_dt

> **Epic**: Overworld Exploration & Encounters
> **Status**: In Progress (2026-10-30): A* half done; the animation-frame clause waits on animated overworld sprites
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-001`, `TR-overworld-005`, `TR-overworld-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012 fixes that `AStarGrid2D.update()` is called only inside the bake, `region`/`cell_size`/`offset` never change afterward, and that sprite animation is driven from the same accumulated `ow_dt` as movement and symbol logic — so a hitch can never desync them.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Probed on 4.7.2: `AStarGrid2D.update()` rebuilds only when dirty; only `region`, `cell_size` or `offset` make the grid dirty; a dirty query logs "Grid is not initialized" and returns `[]`; a solid origin returns `[]` even with `allow_partial_path` (ADR-0012 Engine Compatibility item 10). `AnimationMixer` manual callback mode plus `advance()` exist, which the `ow_dt` animation rule relies on (item 13). After a 600 ms stall, `_process` `delta` reached 0.1333 s, so `dt_max ≤ 0.10` still binds (item 6).

**Control Manifest Rules (this layer)**:
- Forbidden: "Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset`" (control manifest, ADR-0012 §2, probed) — a rebuild clears every solid, and a dirty grid returns empty paths silently.
- Required: "`AStarGrid2D.update()` only inside the bake; `region`, `cell_size` and `offset` frozen afterwards; debug builds assert `not is_dirty()` before every query" (control manifest, ADR-0012 §2).
- Required: "Blocked cells change only through batched `WalkGrid.set_blocked(cells, on)`... one component relabel per frame" (control manifest, ADR-0012 §2).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-59 [L] (pathing setup, one clock)** After bake, `AStarGrid2D.is_dirty()` is false before every query, and `region`, `cell_size` and `offset` never change. A `set_blocked` round trip on one cell leaves every other cell's solid flag unchanged. Over a run with injected hitches, a sprite's animation frame always equals the frame computed from the accumulated `ow_dt`.

---

## Implementation Notes

*Derived from the Edge Cases "Walk-grid pathing setup" and "One clock" sections:*

- Pathing setup: `AStarGrid2D.update()` is called exactly once, at bake. `region`, `cell_size` and `offset` are never changed afterward (changing any of them is the only thing that makes the grid dirty and triggers a rebuild that clears every solid flag and weight). Debug builds must assert `not is_dirty()` before every query (ADR-0012 amendment).
- `set_blocked` round trip: a batched `set_blocked(cells, on)` call followed by `set_blocked(cells, !on)` (or any single-cell on/off round trip) must leave every **other** cell's solid flag exactly as it was — this is the regression `set_blocked` must never cause, distinct from the dirty-grid rebuild risk above.
- One clock: sprite animation is driven from `ow_dt` too — either the mode advances the sprite's frame/progress directly, or its `AnimationPlayer`/`AnimationMixer` runs in manual mode with `advance(ow_dt)` — so animation never drifts from logic, however many hitches occur.
- Hitch robustness: inject frame hitches (deltas larger than `dt_max`) into the test clock and assert the sprite's animation frame always equals the frame computed from the **accumulated** `ow_dt` (which itself is `min(delta, dt_max)` per frame, clamped before accumulation, per Edge Cases "If a frame takes longer than `dt_max`").

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `WalkGrid.bake()`'s `SAFE`-cell rasterisation precision (story 128) — this story assumes the bake already happened correctly and tests what must hold true afterward.
- Component relabelling correctness after `set_blocked` (covered by the AStarGrid2D/`WalkGrid` foundation stories earlier in the epic, outside this writer's range).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/walk_grid.gd` (`is_dirty()` assertion, `set_blocked` round-trip isolation)
- `src/overworld/ground_mover.gd` or `src/overworld/overworld_mode.gd` (sprite animation driven by accumulated `ow_dt`)
- `tests/unit/overworld/walk_grid_pathing_setup_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/walk_grid_pathing_setup_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-leader-speed-from-move-input.md` (AC-1a, `ow_dt` clock foundation)
- Unlocks: None

## Progress Notes (2026-10-30)

- **A* half done.** `tests/unit/overworld/astar_setup_invariants_test.gd`:
  - The A* is built once and never rebuilt.
  - It is not dirty before any query.
  - `region`, `cell_size` and `offset` are unchanged across queries and `set_blocked` calls.
  - A one-cell `set_blocked` round trip changes no other cell's solid flag.
  - Mutation checked: rebuilding the A* per revision fails a test here.
- **Open:** "a sprite's animation frame always equals the frame computed from the accumulated `ow_dt`". The overworld's placeholder sprites show one static frame (`show_frame(&"idle", &"down", ..., 0)`), so there is no animation to test. It lands with the sprite sets (Sprite & Camera Presentation).
