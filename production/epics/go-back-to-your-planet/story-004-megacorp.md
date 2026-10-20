# Story 004: MegaCorp — subscription billing, drones, CEO boss

> **Epic**: Go back to your planet!
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — "MegaCorp (cyberpunk planet): subscription
billing. Each round, every squad member is billed MP, and anyone out of MP is
'suspended' and can only use a basic attack. Enemies are security drones and middle
managers, with a CEO boss."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: None — MegaCorp was never prototyped. The brief itself calls this
"the least proven idea" and puts it right after the core in the build order so it
gets tested early. Expect this story to need iteration.

---

## Acceptance Criteria

*From the brief's MVP feature 4:*

- [ ] At the end (or start) of each round in a MegaCorp battle, every squad member
      loses a fixed amount of MP as a "subscription" charge.
- [ ] A squad member whose MP reaches 0 becomes "suspended."
- [ ] A suspended squad member can only choose Attack (Defend and specials are
      unavailable) until they have MP again.
- [ ] Security drones exist as a regular enemy type for this chapter's non-boss
      fights.
- [ ] Middle managers exist as a second regular enemy type for this chapter's
      non-boss fights.
- [ ] The CEO is a boss enemy with more HP than a drone or middle manager.
- [ ] The battle is still winnable: a squad member who stays suspended for a whole
      fight (never regains MP) does not make the fight unwinnable by design.

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria and the prototype reference above.*

- This rule is new and unproven — build the simplest version that meets the
  Acceptance Criteria, test it in-engine per the battle core's turn flow, and
  expect to tune the billing amount once it's playable. The brief does not fix a
  specific MP amount per round; pick one that lets a normal-length fight still be
  winnable by a squad relying mostly on Attack, and record the chosen value in this
  story's implementation (do not invent a different mechanic to avoid picking a
  number).
- Reuse Story 001's win/loss and Story 003's MP-cost gating rather than building a
  parallel resource system.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the base MP/HP/win-loss/retry engine this rule sits on.
- Story 003: the specials themselves (this story only restricts their use when suspended).
- Story 005: any visual presentation of the billing/suspension state.
- Story 006: chaining this battle into the planet's 3-fights-then-boss chapter.

---

## Files

- `src/battle/factions/megacorp.gd`
- `src/battle/factions/faction_rule.gd`
- `src/battle/battle_core.gd`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/megacorp/megacorp_test.gd` — advisory (waived) at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-001-battle-core.md`, `production/epics/go-back-to-your-planet/story-003-squad-specials.md`
- Unlocks: `production/epics/go-back-to-your-planet/story-005-battle-hud.md`, `production/epics/go-back-to-your-planet/story-006-chapter-flow.md`

---

## Completion Notes

**Completed**: 2026-10-20
**Criteria**: 7/7 passing (none deferred)
**Deviations**: ADVISORY — MP billing amount, enemy stats, and attack powers are hardcoded consts in `src/battle/factions/megacorp.gd` rather than an external data file, matching the existing pattern in `bureaucratia.gd`/`specials.gd`.
**Test Evidence**: waived at `qa.level: minimal`
**Reviewed by**: self, no independent review (solo mode)
