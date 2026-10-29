# Story 016: Spent and resolved interactables drop out of probe(); repeatable ones stay targetable

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A target is eligible only while `confirm` would do something: an open checkpoint, an already-changed `change` gag, and a liberated marker drop out of `probe()` entirely; a `line` or `clue` gag stays eligible and repeats its line (a granted clue adds no second rumour); NPCs and CampSpots are always eligible.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure state-flag checks against `WorldState`'s opened/liberated/granted-payoff records; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Interaction is one `probe()` (nearest eligible target...)" — source: ADR-0012 §6 (eligibility is the gate before distance/tie-order even run)
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-7f [L] (R3, eligibility)** GIVEN an open checkpoint, a `change` gag already changed and a liberated marker within reach, THEN `probe()` returns none of them and no prompt is drawn. GIVEN a `line` gag already used, THEN it is still targeted and repeats its line (or its alternate). GIVEN a `clue` gag used again, THEN no second rumour is added.

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3's Eligibility clause:*

GDD rule 3: "A target is eligible only while `confirm` would do something: an
open checkpoint, a `change` gag already changed, and a liberated marker drop
out of `probe()`; a `line` or `clue` gag stays eligible and repeats its line
(a short alternate line if the record has one). A granted clue adds no
second rumour."

- Fixture: an open checkpoint, an already-`change`d gag, and a liberated marker, all within `interact_reach_m` of the probe point — assert `probe()` returns null for each individually and the prompt stays hidden.
- A `line` gag already used must still be returned by `probe()`, and a repeat `confirm` must replay its line (or its alternate line, if the record has one) — not silently no-op.
- A `clue` gag used a second time must still be targetable (eligible) but must add no second Codex rumour (the interim stub dialogue line still plays, per ADR-0012 §6, but the rumour grant is a once-only side effect tracked in `WorldState.grant_payoff`-style bookkeeping, re-used here for gags).
- This story's fixture assumes targets are otherwise in reach and untied (story 011's concern); it isolates only the eligibility predicate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: distance/tie-order among eligible targets.
- Story 021d (outside this batch): the off-screen sting plus payoff-card pairing for a Victory whose marker is off-screen — a different "repeat" concern (liberation, not gag eligibility).

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/world_state.gd`
- `tests/unit/overworld/probe_eligibility_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/probe_eligibility_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`
- Unlocks: None

## Completion Notes (2026-10-30)

- Liberated markers do not exist yet (rule 9; stories 059-060), so that clause has nothing to check. Open checkpoints, changed `change` gags, repeating `line` gags (alternate line) and once-only `clue` rumours are covered.
- New: `NpcSpawn` and `GagInteractable` markers; the segment carries a civilian with the rule 16 teaching line and the permit clue poster (`faction_clue`, rumour `rumour_permit_ban`).
