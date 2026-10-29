# Story 097: Every row of the Overworld state table enters and exits correctly

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`, `TR-overworld-011`, `TR-overworld-012` (no single TR covers the whole state table — these three are the closest-matching combination: encounter start/thaw, checkpoint redirect, and map change together span every row)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (battle request, thaw, transitions, `register_camp`, in-mode fade)
**ADR Decision Summary**: `OverworldMode`'s states — Exploring, Interacting/Dialogue, Redirecting, CampPrompt, EncounterStarting, Frozen, MapChanging, Paused — are driven entirely by Game State's transition, overlay and thaw machinery (ADR-0002), with the Overworld supplying only the request payloads (ADR-0012 §4–§6).
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21 (§11 revised 2026-10-23)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Relies on the probed `GameStateMachine` detach/freeze and signal-ordering behaviour (ADR-0002 Engine Compatibility: `remove_child`/`add_child` fire `_ready()` once in total; a detached `Timer` freezes and resumes).

**Control Manifest Rules (this layer)**:
- Required: "Map change swaps to a fresh instance: it detaches the old mode, adds the new one, and frees the old only on success (rollback re-adds it)" — source: ADR-0012 §4, ADR-0002 §2 and annotation (a)
- Required: "A failed checkpoint's redirect closes the Dialogue and then calls `machine.request_in_mode_fade(callback)`" — source: ADR-0012 §2, §6

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-37 [L] (States and Transitions)** Parametrized over every row of the table: each entry produces its state, and each listed exit produces its target. A rejected encounter returns to Exploring. A failed map load restores the old map.

---

## Implementation Notes

*Derived from the GDD "States and Transitions" table and ADR-0012 §4–§6:*

- Parametrize the test over every row: **Exploring**, **Interacting/Dialogue**, **Redirecting**, **CampPrompt**, **EncounterStarting**, **Frozen (in battle)**, **MapChanging**, **Paused (Menu)**. For each row's Entry condition, assert the mode reaches that state; for each listed Exit, assert it reaches the named target.
- Two named special cases from the table, asserted explicitly:
  - A **rejected** encounter (`EncounterStarting`, the transition refused) returns to **Exploring**, with the touched symbol held in contact pending (rule 5) and contact re-tested next frame.
  - A **failed** map load (`MapChanging`) restores the **old** map — `rollback_swap()` re-adds the detached instance rather than completing the swap.
- The café's chapter-final-step branch (`Exploring` → the P15 "End the chapter here?" prompt, rule 13) and the ordinary `CampPrompt` branch are distinct rows — do not collapse them.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Permit Counter's own Static branch within `EncounterStarting`/`Frozen` (story 091, already covered there).
- `Continue`'s per-visit reset on reaching `Exploring` from a load (story 096).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/overworld_state_table_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_state_table_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-091-permit-counter-static-behavior.md`, `production/epics/overworld-exploration-encounters/story-096-continue-resets-symbols-to-patrol-origin.md`, `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`
- Unlocks: None further in this epic
