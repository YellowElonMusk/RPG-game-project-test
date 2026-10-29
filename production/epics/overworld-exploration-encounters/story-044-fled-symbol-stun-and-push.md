# Story 044: Fled stuns a non-Static symbol and pushes it back along the contact line

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

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`on_thawed`, `BattleResult.FLED`)
**ADR Decision Summary**: `on_thawed` for Fled on a non-Static symbol enters Stunned and moves the symbol back by up to `flee_push_m` in 4-connected steps along the leader-to-symbol line; the leader never moves.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `BattleResult.FLED` is a foundational `GameStateMachine` enum value (ADR-0002); HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: `on_fled(leader, leader_facing, grid, cfg)` moves a non-Static symbol 4-connected, never diagonally between two blocked corners — ADR-0012 §5, Key Interfaces
- Forbidden: Never move the leader on a Fled result; never push a Static symbol
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-19a [L] (R7, Edge Cases)** GIVEN Fled from a non-Static symbol, THEN in `on_thawed` the symbol is Stunned, and it is moved along the leader-to-symbol line by `flee_push_m` in 4-connected cell steps, or less if a non-symbol-legal cell comes first. The leader's position is unchanged.

---

## Implementation Notes

*Derived from ADR-0012 §5, Key Interfaces (`SymbolBrain.on_fled`) and GDD Edge Cases ("If the flee push meets a wall..."):*

- Drive a Fled result through `on_thawed` for a non-Static (Patrol/Chasing) symbol; assert its sub-state becomes Stunned and its new position lies along the leader-to-symbol line, exactly `flee_push_m` away, moved in **4-connected** cell steps (never a diagonal hop between two blocked corners).
- Fixture a push that meets a blocker before covering the full `flee_push_m`; assert the symbol stops at the first non-symbol-legal cell, covering less than `flee_push_m` — do not assert it always reaches the full distance.
- Assert the leader's `party_pos` is byte-for-byte unchanged by the push (GDD rule 7: "The leader never moves").
- This story's push always has a well-defined leader-to-symbol direction; the degenerate coincident-centres case is story 046's scope.

---

## Out of Scope

- `story-043-victory-respawn-policy.md`: the Victory branch of `on_thawed`.
- `story-045-stunned-symbol-grants-no-encounter.md`: behaviour once Stunned.
- `story-046-flee-push-coincident-centres.md`: the coincident-centres push direction.

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/symbol_brain_fled_push_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_fled_push_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-043-victory-respawn-policy.md`, `game-state-scene-flow/story-016-fled-rejected-when-not-allowed.md`
- Unlocks: `story-045-stunned-symbol-grants-no-encounter.md`, `story-046-flee-push-coincident-centres.md`
