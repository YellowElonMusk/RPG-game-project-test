# Story 132: A narrow aspect logs one warning; a freed blocker invalidates stale paths

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`, `TR-overworld-002`, `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0005 fixes that `chase_visibility` is checked at 4:3, 16:9 and 21:9, with aspects narrower than 4:3 unsupported; ADR-0012 fixes that `WalkGrid.set_blocked()` invalidates stored paths and the notice cache on every change.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface. Reuses the already-probed component relabel and `set_blocked` batching (ADR-0012 Engine Compatibility items 7, 12).

**Control Manifest Rules (this layer)**:
- Required: "Blocked cells change only through batched `WalkGrid.set_blocked(cells, on)`, which updates both grids, invalidates stored paths and notice caches, and marks the 4-connected component labels for one relabel per frame" (control manifest, ADR-0012 §2).
- Guardrail: "Component relabel: one full pass costs ~0.83 ms on 60×60 (probed); batch `set_blocked` and relabel at most once per frame" (control manifest, ADR-0012 §2).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-55 [L] (Edge Cases)** GIVEN a window aspect narrower than 4:3, THEN exactly one warning is logged and the game runs. GIVEN a blocker freed while a symbol's path ran round it, THEN the stored path and notice cache are invalidated, and the symbol's next repath in its stagger turn crosses the freed cells.

---

## Implementation Notes

*Derived from the Edge Cases list:*

- Aspect warning: "If the window is resized: Presentation recomputes the footprint. `chase_visibility` is checked at 4:3, 16:9 and 21:9, so no supported aspect breaks it. Aspects narrower than 4:3 are unsupported, and a warning is logged." Assert **exactly one** warning is logged per resize event (not one per frame while the narrow aspect persists), and that the game continues running rather than halting.
- Freed blocker: "If a blocker is freed while a symbol's path ran round it: `set_blocked` invalidates stored paths and the notice cache, and updates the component labels. The symbol's next repath (in its stagger turn) uses the freed cells. Nothing is recomputed out of turn."
  - Setup: a symbol has an active path routed around a blocked cell; free that cell via `set_blocked(cells, false)`.
  - Assert: the symbol's stored path and notice cache are both invalidated immediately (not lazily), but the symbol does **not** repath out of turn — it repaths only on its next scheduled turn through the `repath_per_frame_max` round-robin cursor (rule 5 Query budget), and that repath must be free to cross the now-freed cells.
- Both are genuine edge cases, not everyday paths — the test fixtures should isolate each condition precisely (a window resize event; a blocker toggled off mid-chase) rather than relying on incidental triggers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The general `set_blocked` round-trip isolation guarantee (story 131) — this story is specifically about the freed-blocker/repath-timing edge case, not general solid-flag correctness.
- The follow camera's own `chase_visibility` formula at each aspect (outside this writer's range) — this story only checks the warning-logging behaviour at an unsupported aspect.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/walk_grid.gd` (`set_blocked` cache/path invalidation on free)
- `src/overworld/symbol_brain.gd` (stagger-turn repath after invalidation, never out of turn)
- `tests/unit/overworld/aspect_warning_and_freed_blocker_test.gd` (aspect warning count; freed-blocker repath timing)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/aspect_warning_and_freed_blocker_test.gd` — must exist and pass.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-029-bounded-notice-search-cap.md` (AC-9k, bounded notice search / query budget), `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md` (follow camera, `chase_visibility`)
- Unlocks: None

## Completion Notes (2026-10-30)

- New: `FollowCamera.note_resize(aspect)`, connected to the viewport's `size_changed`. Each resize to an aspect under 4:3 logs exactly one warning, counted in `narrow_aspect_warnings`, never one per frame. The camera keeps stepping.
- Freed blocker: already built. `set_blocked` bumps the grid revision, which marks the stored route and the notice cache stale at once. The repath still waits for the symbol's `repath_s` turn, then routes through the freed cells.
- Mutation checked: repathing out of turn on a revision change fails a test here.
