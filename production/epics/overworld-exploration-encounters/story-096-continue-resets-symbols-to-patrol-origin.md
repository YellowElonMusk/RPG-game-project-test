# Story 096: A Continue made mid-chase starts every symbol in Patrol at its origin

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-014`, `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: Per-visit symbol state (sub-state, position along a patrol, cooldowns) is never saved; a `LoadedSave` entry never applies `on_map_reenter` respawn, so a saved, resolved symbol stays absent while every unresolved symbol rebuilds fresh in Patrol at its marker origin, with grace starting on the reveal.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No engine-specific behaviour beyond the plain `OverworldMode._ready()` build order (ADR-0012 §4).

**Control Manifest Rules (this layer)**:
- Required: "Entry paths: … `LoadedSave` → saved position, **no respawn** …" — source: ADR-0012 §4
- Required: "`OverworldMode extends GameMode` holds only per-visit state: actor positions, symbol brains, the trail, timers" — source: ADR-0012 §4

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-36 [I] (Edge Cases)** GIVEN a save made mid-chase with a resolved `on_map_reenter` Clerk, WHEN Continue runs, THEN every symbol is in Patrol at its origin, the resolved Clerk stays absent, and grace starts on the reveal.

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD Edge Cases ("If the player saves mid-chase, then Continues"):*

- Per-visit symbol state (sub-state, position along the patrol path, notice/give-up/cooldown timers) is never saved — only `WorldState`'s resolved-symbols record persists.
- Fixture: save while one Clerk chases the leader and a second, `on_map_reenter`-respawn Clerk is already resolved (beaten earlier this visit) elsewhere on the map. Continue.
- Assert: every unresolved symbol rebuilds in `Patrol`, at its marker's origin — never mid-chase, never mid-patrol-path. The resolved Clerk stays absent (`on_map_reenter` respawn is **not** applied on a `LoadedSave` entry). Encounter grace starts on this reveal, exactly as it does after every map load.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The content of what gets saved (story 095).
- The states table's `MapChanging` rollback path (story 097).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/integration/overworld/continue_resets_symbols_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/continue_resets_symbols_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-095-save-round-trips-camp-interactables-and-flags.md`, `production/epics/overworld-exploration-encounters/story-092-story-flag-order-after-battle.md`
- Unlocks: None further in this epic
