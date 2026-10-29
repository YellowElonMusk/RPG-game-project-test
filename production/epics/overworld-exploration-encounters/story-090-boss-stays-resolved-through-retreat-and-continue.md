# Story 090: A later Retreat, a Save and a reload never un-resolve the boss

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-014`, `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (Retreat discards only the frozen overworld instance)
**ADR Decision Summary**: A boss Victory writes its `respawn = never` resolution into `WorldState` in `on_thawed`; a later fight's Retreat discards only that frozen overworld instance and never touches the resolved-symbols record, which `WorldState` — the single owner of state that outlives a visit — then carries through Save and Continue unchanged.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface beyond `WorldState`'s plain `RefCounted` fields; relies on the same probed detach/freeze behaviour as story 089.

**Control Manifest Rules (this layer)**:
- Required: "`WorldState` … is the single owner of … state that outlives a visit (… resolved/opened/liberated per map …)" — source: ADR-0012 §4
- Required: "If the boss is defeated: `respawn = never` is written to world state in `on_thawed`. A Retreat in any later fight discards only the frozen overworld, so the boss stays resolved, after a Continue too" — source: GDD Edge Cases

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-33c [I] (R13)** After Victory over the boss, then a Retreat in a later fight, then Save, Continue and a reload, the boss stays absent.

---

## Implementation Notes

*Derived from ADR-0012 §4, §5 and GDD rule 13 / Edge Cases ("If the boss is defeated"):*

- Sequence: Victory over the boss (writes `respawn = never` to `WorldState` in `on_thawed`) → a later, unrelated encounter → Defeat → Retreat (discards only that frozen overworld instance, per `game-state-scene-flow.md` rule 8; `WorldState`'s resolved-symbols record is untouched) → Save (at a Game State safe moment, rule 15) → Quit → Continue.
- Assert the boss is still absent (its marker still resolves `is_resolved(map_id, symbol_id) == true`) after the full round trip, and that reaching its chamber again shows no boss.
- This exercises the same save-round-trip mechanics as story 095, scoped specifically to the boss's `respawn = never` resolution surviving an intervening Retreat.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The general save/load round trip of camp, interactables, payoffs, liberation and story flags (story 095).
- Retreat's destination logic (story 089).

---

## Files

- `tests/integration/overworld/boss_resolution_persists_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/boss_resolution_persists_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-088-boss-contact-descriptor-flags.md`, `production/epics/overworld-exploration-encounters/story-089-story-encounter-flee-returns-to-registered-camp.md`, `production/epics/overworld-exploration-encounters/story-095-save-round-trips-camp-interactables-and-flags.md`
- Unlocks: None further in this epic
