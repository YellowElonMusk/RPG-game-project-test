# Story 070: A checkpoint opens on a met requirement and stays open across save and load

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A checkpoint is one generic `Interactable` kind; meeting its single requirement on `confirm` plays the stamp moment, opens it, saves it as opened, and frees its cells through `set_blocked`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Opening a checkpoint changes blocked cells only through the batched `set_blocked(cells, on)` path, which invalidates stored symbol paths and bumps the component-relabel flag — no new API beyond that already-probed path.

**Control Manifest Rules (this layer)**:
- Required: Blocked cells change only through batched `WalkGrid.set_blocked(cells, on)`, which updates both grids, invalidates stored paths and notice caches, and marks the 4-connected component labels for one relabel per frame — source: ADR-0012 §2
- Forbidden: Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset` — source: ADR-0012 §2
- Guardrail: Component relabel: one full pass costs ~0.83 ms on 60×60; batch `set_blocked` and relabel at most once per frame — source: ADR-0012 §2

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-28a [L] (R10)** GIVEN a met requirement, THEN `confirm` opens the checkpoint, its cells are freed, and it stays open across save and load. GIVEN the requirement already met on load, THEN it stays closed until `confirm`.

---

## Implementation Notes

*Derived from GDD rule 10 ("Success") and the Edge Cases list:*

- Rule 10, Success: if the requirement is met when `confirm` is pressed, the stamp moment plays, the checkpoint opens, and it stays open (saved via `WorldState.mark_opened`); its cells are freed.
- Edge case: "If a checkpoint's requirement is already met when the map loads: it stays closed until `confirm`. On `confirm` it opens with no failure branch, and the stamp moment is the joke."
- Each checkpoint has exactly one requirement (an item ID or a story flag, rule 10) — this story implements the success branch only; the failure branches are story-071 (`redirect`/`queue`) and story-072 (`encounter`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-071-checkpoint-redirect-and-queue-failure: the `redirect`/`queue` failure outcomes (AC-28b)
- story-072-checkpoint-encounter-outcome: the `encounter` failure outcome (AC-28c)

---

## Files

- `src/overworld/overworld_mode.gd` (checkpoint `confirm` handling)
- `src/overworld/world_state.gd` (`mark_opened`)
- `src/overworld/walk_grid.gd` (`set_blocked` on open)
- `tests/unit/overworld/checkpoint_met_requirement_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/checkpoint_met_requirement_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md` (`probe()`/interaction, AC-7a)
- Unlocks: `production/epics/overworld-exploration-encounters/story-071-checkpoint-redirect-and-queue-failure.md`, `story-072-checkpoint-encounter-outcome.md`

## Completion Notes (2026-10-30)

- The behaviour already existed (stories 072 and 093); this story adds its own evidence test.
- Mutations checked: auto-opening a checkpoint whose requirement is met on load, and not saving opened checkpoints, each fail a test here.
