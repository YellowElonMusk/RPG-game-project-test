# Story 050: The first Victory over a symbol grants its payoff and shows a payoff card

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`on_thawed` / `transition_finished` ordering)
**ADR Decision Summary**: `WorldState.grant_payoff(map_id, symbol_id)` returns false if already granted, so a payoff is only ever handed out once; the payoff card shows on `transition_finished`, naming the result.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Card timing rides the same `transition_finished` contract as story 047; HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: First-Victory payoffs per `enc_` record, granted once, announced by a non-blocking payoff card — ADR-0012 Summary, GDD rule 7a
- Forbidden: Never grant a payoff twice for the same marker, even across a respawned Clerk
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-21b [L] (R7a)** GIVEN a first Victory over a symbol with each payoff type, THEN `clue` adds one Codex rumour (or calls the interim stub), `open` opens the linked checkpoint, and `item` adds the item. On `transition_finished` the payoff card shows one line naming the result. A second Victory over the respawned Clerk grants nothing and shows no card.

---

## Implementation Notes

*Derived from GDD rule 7a ("Victory payoff") and ADR-0012 §5 (`WorldState.grant_payoff`):*

- Fixture one symbol per payoff type (`clue`, `open`, `item`) and drive a first Victory for each: assert `clue` adds exactly one Codex rumour (or calls the interim stub dialogue line, per rule 7a, until Combo System & Codex exists), `open` opens its linked checkpoint, and `item` adds the named item.
- Assert the payoff card appears on `transition_finished` (step 2 of the thaw) with exactly one line naming what was granted (rule 7a: "Shortcut opened: Rue des Tampons", "Rumour noted in the Codex", "Got: Form 27-B" are the GDD's own examples — use the fixture's own text, not these literals, since text is data per `LocText`).
- Respawn the same Clerk (via `respawn = on_map_reenter`, story 043's mechanism) and drive a second Victory: assert `grant_payoff` returns false, nothing is added/opened a second time, and no payoff card shows.
- `none` payoffs are covered by this same mechanism (granting nothing, showing the ordinary victory feedback with no card) but are only data-constrained (at most ⌊N_sym/3⌋ per map, never the first symbol) — that data constraint is story 051's scope, not this one's.

---

## Out of Scope

- `story-043-victory-respawn-policy.md`: the respawn mechanism this story reuses for its "second Victory" fixture.
- `story-051-map-payoff-distribution-rules.md`: the data-level payoff distribution rules (facets, `none` caps, tells).
- `story-052-offscreen-liberation-payoff-card.md`: the off-screen liberation sting paired with the card.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/world_state.gd`
- `tests/unit/overworld/overworld_mode_first_victory_payoff_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_first_victory_payoff_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing; evidence `production/qa/evidence/story-050-victory-payoff/`

---

## Dependencies

- Depends on: `story-043-victory-respawn-policy.md`
- Unlocks: `story-051-map-payoff-distribution-rules.md`, `story-052-offscreen-liberation-payoff-card.md`

## Completion Notes (2026-10-30)

- `EncounterData.victory_payoff` shape defined: `{type: clue|open|item|none, facet, text, checkpoint, item_id, label}`. Rumours and items are interim `rumour:` / `item:` flags in `WorldState` until the Codex and an inventory exist; item requirements on checkpoints now read them.
- Paris content: both Clerk records carry `clue` payoffs with distinct facets (three-round wait; binds both sides). The rule-7a content rules (at least one `open` per map, `none` limits, tells) are story 051.
