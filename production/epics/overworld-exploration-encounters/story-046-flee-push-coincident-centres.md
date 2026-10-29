# Story 046: A flee push with coincident centres goes opposite the leader's facing

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
**ADR Decision Summary**: `on_fled` needs a direction to push along; when the leader's and symbol's centres coincide there is no leader-to-symbol vector, so the push goes along the direction opposite the leader's facing instead.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Pure vector-degeneracy handling; HIGH risk here follows only from ADR-0002's own rating on the surrounding `BattleResult.FLED` contract, not from this specific branch.

**Control Manifest Rules (this layer)**:
- Required: `on_fled(leader, leader_facing, grid, cfg)` must resolve a push direction even at zero separation — ADR-0012 §5, Key Interfaces
- Forbidden: Never let a coincident-centres push divide by zero or pick an arbitrary/undefined direction
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-19c [L] (Edge Cases)** GIVEN Fled with coincident centres, THEN the push goes along the direction opposite the leader's facing.

---

## Implementation Notes

*Derived from GDD Edge Cases ("If the flee push meets a wall... If the two centres coincide, the push goes along the direction opposite the leader's facing"):*

- Fixture a Fled result where the leader's and symbol's positions are exactly equal at the moment `on_thawed` runs; assert the push direction equals the negation of `leader_facing`, not a zero vector, not the symbol's own stored facing, and not an arbitrary default axis.
- Parametrize `leader_facing` across at least the four cardinal-ish directions the sprite set shows (the diagonals, per ADR-0005 facing snap) to prove the negation is computed from the actual facing each time, not hardcoded.
- Still apply the 4-connected step rule and the `flee_push_m`/blocker-stop rule from story 044 — this story only replaces how the *direction* is chosen when centres coincide; the stepping mechanics are shared.

---

## Out of Scope

- `story-044-fled-symbol-stun-and-push.md`: the ordinary (non-coincident) push direction and distance.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_fled_coincident_push_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_fled_coincident_push_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-044-fled-symbol-stun-and-push.md`
- Unlocks: None
