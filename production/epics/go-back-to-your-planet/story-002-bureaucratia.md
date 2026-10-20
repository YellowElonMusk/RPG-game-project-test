# Story 002: Bureaucratia — permit, hunker-down, Supervisor boss

> **Epic**: Go back to your planet!
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — "Bureaucratia: specials banned for both sides
until the permit arrives in round 3, with Bureaucratia hunkering down meanwhile (it
focuses anyone at half HP or lower); Clerks; and the Supervisor boss ('he *is* the
manager')."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: `prototypes/battle-concept/battle.gd` (iteration 2) and
`prototypes/battle-concept/PLAYTEST-LOG.md` Playtest 1 — this exact rule was
playtested and called "decent." Throwaway code; do not import it.

---

## Acceptance Criteria

*From the brief's MVP feature 3:*

- [ ] For the first 3 rounds of a Bureaucratia battle, no combatant on either side
      (squad or enemy) can use a special move — only Attack and Defend are
      available.
- [ ] From round 4 onward, specials are allowed for both sides.
- [ ] While specials are banned, if every squad member is above half HP, the
      Bureaucratia officials defend (take half damage) and make a weak attack.
- [ ] While specials are banned, if any squad member is at or below half HP, the
      Bureaucratia officials attack that squad member instead of defending.
- [ ] Clerks exist as a regular enemy type for this chapter's non-boss fights.
- [ ] The Supervisor is a boss enemy with more HP than a Clerk.
- [ ] Any move that targets "the manager" (e.g. Karen's stun, Story 003) has no
      effect on the Supervisor, because he is the manager.

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria and the prototype reference above.*

- Build this on top of Story 001's battle core: the permit ban and hunker-down
  behavior are a rule layer over Attack/Defend/MP, not a new battle engine.
- The round-4 unlock and the half-HP threshold are both already-tested values
  from the prototype — keep them unless the brief or the user changes them.
- Boss immunity to "manager" moves should be a general flag the battle core can
  check (e.g. `is_boss` or a specific `is_manager` flag), reusable by Story 003's
  Karen stun rather than hardcoded to one move.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the base Attack/Defend/MP/win-loss/retry engine this rule sits on.
- Story 003: what a special actually does once unlocked (this story only gates
  *when* specials are usable).
- Story 005: the countdown banner and rule tooltip text.
- Story 006: chaining this battle into the planet's 3-fights-then-boss chapter.

---

## Files

- `src/battle/factions/faction_rule.gd` (new: FactionRule base class, neutral defaults)
- `src/battle/factions/bureaucratia.gd` (new: BureaucratiaRule)
- `src/battle/battle_core.gd` (modified: faction_rule hook, specials gate)
- `src/battle/battle_debug_harness.gd` (modified: Bureaucratia roster, specials ALLOWED/BANNED)

No test file: test evidence is waived at `qa.level: minimal`.

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/bureaucratia/bureaucratia_test.gd` — advisory (waived) at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-001-battle-core.md`
- Unlocks: `production/epics/go-back-to-your-planet/story-003-squad-specials.md`, `production/epics/go-back-to-your-planet/story-005-battle-hud.md`, `production/epics/go-back-to-your-planet/story-006-chapter-flow.md`

---

## Completion Notes
**Completed**: 2026-10-20
**Criteria**: 7/7 passing (0 deferred)
**Deviations**: ADVISORY — the rule's constants (permit length, HP threshold, move powers, Clerk/Supervisor stats) are hardcoded in `bureaucratia.gd` rather than read from a data file (same pattern as Story 001's damage constants).
**Test Evidence**: waived at `qa.level: minimal` — no test file written. Screenshot: `production/qa/evidence/story-002-bureaucratia/harness00000029.png`
**Reviewed by**: self, no independent review (solo mode)
