# Story 043: Victory resolves the symbol per its record's respawn policy

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`on_thawed`, called after `mode_entered`)
**ADR Decision Summary**: In `on_thawed`, Victory resolves the symbol per its record's `respawn` policy: `on_map_reenter` symbols are gone until the map is left and loaded again; `never` symbols stay gone across any number of reloads.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `GameMode.on_thawed(encounter_id, result)` is called only on the Overworld mode, after `mode_entered` (ADR-0002 Key Interfaces) — a foundational, pre-4.0 callback pattern; HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: Two-step thaw — all state changes in `on_thawed` under the wipe (resolve, payoff, liberation, stun/push or Static return) — ADR-0012 §5
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — resolution belongs in `on_thawed`, after the swap succeeds
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-18 [L] (R7)** GIVEN Victory over a normal Clerk, THEN it is absent until the map is reloaded through a MapExit, and present after that. GIVEN Victory over a `respawn = never` record, THEN it is absent after any number of reloads.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 7 ("Victory"):*

- Fixture a normal Clerk (`respawn = on_map_reenter`); drive a Victory through `on_thawed`; assert `world_state.is_resolved(map_id, symbol_id)` is true and the symbol is absent for the remainder of the current visit, then simulate a MapExit reload and assert it reappears (resolved state cleared on `on_map_reenter`, per `WorldState.on_map_entered`'s entry-kind handling).
- Fixture a `respawn = never` record (representative of the boss/story-encounter policy, though this story's scope is the generic resolution mechanism, not rules 13/13a specifically); drive Victory, then simulate **two** successive map reloads and assert the symbol stays absent after both.
- Assert the resolution write happens inside `on_thawed`, not before — a test that calls `on_thawed` directly (per the harness's injectable mode clock / Game State stub) is sufficient; this story does not need the full transition round trip, which is story 049's integration-level concern.

---

## Out of Scope

- `story-044-fled-symbol-stun-and-push.md`: the Fled branch of `on_thawed`.
- `story-050-first-victory-grants-payoff.md`: the payoff granted alongside resolution.
- `story-049-thaw-preserves-mid-chase-snapshot.md`: the full Battle round-trip integration test.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/world_state.gd`
- `tests/unit/overworld/overworld_mode_victory_respawn_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_victory_respawn_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-038-contact-starts-encounter-once.md`, `game-state-scene-flow/story-015-victory-waits-for-results.md`
- Unlocks: `story-050-first-victory-grants-payoff.md`, `story-052-offscreen-liberation-payoff-card.md`
