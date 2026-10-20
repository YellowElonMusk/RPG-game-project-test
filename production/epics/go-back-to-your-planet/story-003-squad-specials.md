# Story 003: Squad specials — Karen, Chef, Florida Man, Baguette Thrower

> **Epic**: Go back to your planet!
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 — "The squad, four recruits with their
specials: Karen's *Speak to the Manager* stuns one enemy, but not bosses. The Chef
has *Family Meal* (heals the whole party) and *Appetizer* (heals one ally). Florida
Man's *Viral Stunt*. Baguette Thrower's *Home Run*."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: `prototypes/battle-concept/battle.gd` (iteration 2) implements a
close version of all four specials except Appetizer, which is new in the brief.
Throwaway code; do not import it.

---

## Acceptance Criteria

*From the brief's MVP feature 2, gated by Story 002's permit-ban rule where that rule is active:*

- [ ] Karen has a special, *Speak to the Manager*, that spends MP and stuns one
      target enemy (it loses its next turn).
- [ ] *Speak to the Manager* has no effect when used on a boss (the boss "is the
      manager" — reuse Story 002's boss/manager flag).
- [ ] The Michelin Chef has a special, *Family Meal*, that spends MP and heals every
      living squad member using the heal formula in
      `design/gdd/stats-damage-resolution.md` (F4).
- [ ] The Michelin Chef has a second special, *Appetizer*, that spends MP and heals
      one chosen squad member.
- [ ] Florida Man has a special, *Viral Stunt*, that spends MP and increases damage
      taken by one target enemy for a limited number of rounds.
- [ ] Baguette Thrower has a special, *Home Run*, that spends MP and deals damage to
      one target enemy, using the same damage pipeline as Attack but with its own
      power value.
- [ ] Every special is unusable while a faction's specials-ban rule is active (e.g.
      Bureaucratia's permit-pending rounds, Story 002), and usable once that rule
      lifts.
- [ ] A special that costs more MP than the user currently has cannot be selected.

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria and the prototype reference above.*

- Build each special as a move the battle core (Story 001) already knows how to
  cost, target and resolve — do not create a separate system parallel to Attack/Defend.
- The boss/manager immunity flag should be the same one Story 002 introduces for
  the Supervisor, not a second one-off check.
- Appetizer is new versus the prototype: it is Family Meal's single-target sibling.
  Use the same heal formula (F4) with one target instead of the whole party.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the general move/MP/targeting plumbing specials are built on.
- Story 002: when specials are allowed to be used (the permit-ban gate itself).
- Later (Out of Scope in the brief): the Chef's offensive dishes (spicy chilli
  burn and blind) — not in this MVP.
- Story 005: any visual/tooltip presentation of these specials.

---

## Files

- `src/battle/squad/specials.gd`
- `tests/unit/squad/squad_specials_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/squad/squad_specials_test.gd` — advisory (waived) at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-001-battle-core.md`, `production/epics/go-back-to-your-planet/story-002-bureaucratia.md`
- Unlocks: `production/epics/go-back-to-your-planet/story-004-megacorp.md`
