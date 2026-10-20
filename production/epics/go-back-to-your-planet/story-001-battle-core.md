# Story 001: Battle core

> **Epic**: Go back to your planet!
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — "Battle core: turn-based combat with Attack,
Defend, specials, MP, win/lose and retry, using the Stats & Damage formulas
(`design/gdd/stats-damage-resolution.md`)."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: `prototypes/battle-concept/battle.gd` and
`prototypes/battle-concept/REPORT.md` proved this core (PROCEED verdict). It is
throwaway code — do not import it — but its math and turn flow are the reference.

---

## Acceptance Criteria

*From the brief's Player goal & fail state and MVP feature 1:*

- [ ] A battle has a squad side and an enemy side, each combatant with HP and MP.
- [ ] Turn order lets every living squad member act once, then every living enemy
      acts once, then the round repeats.
- [ ] A combatant can choose Attack (damage an enemy) or Defend (take half damage
      until their next turn) each turn, using the formulas in
      `design/gdd/stats-damage-resolution.md` (F3 base damage, F6 variance, F7
      round/clamp).
- [ ] A knocked-out combatant (HP reaches 0) is skipped in turn order and cannot be targeted by damage.
- [ ] When every enemy is knocked out, the battle ends in a win.
- [ ] When every squad member is knocked out, the battle ends in a loss — per the
      brief's fail state, the player can retry the battle from its start with no
      permadeath and no lost progress.
- [ ] Specials exist as a move category with an MP cost, distinct from Attack and
      Defend (their individual effects are Story 003's scope — this story only
      needs the cost/target/resolve plumbing to exist).
- [ ] Damage and MP changes are reported in a way a later HUD story can display
      (an outcome per action), even though this story has no HUD of its own.

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria and the prototype reference above.*

- Base the damage/heal pipeline on `design/gdd/stats-damage-resolution.md` F3–F7:
  ratio damage (`power/10 × atk²/(atk+def)`), ±10% variance, round-half-up, clamp
  to a minimum of 1.
- Keep this story's own UI minimal (placeholder text/buttons are fine) — the real
  HUD is Story 005. Build only enough to test the state machine manually and in
  code.
- Do not implement any faction-specific rule (permit ban, billing) here — that is
  Stories 002 and 004. This story's Attack/Defend/MP/win-loss/retry must work with
  no faction rule active.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Bureaucratia's permit-pending restriction, hunker-down AI, Supervisor boss.
- Story 003: each special's actual effect (stun, heal, viral, home run).
- Story 004: MegaCorp's subscription billing and suspension.
- Story 005: HP/MP bars, rule banner, floating numbers, tooltips.
- Story 006: chaining battles into a 3-fights-then-boss chapter.

---

## Files

- `src/battle/combatant.gd`
- `src/battle/move.gd`
- `src/battle/battle_outcome.gd`
- `src/battle/damage_calculator.gd`
- `src/battle/battle_core.gd`
- `src/battle/battle_debug_harness.gd`
- `src/battle/battle_debug_harness.tscn`

No test file: test evidence is waived at `qa.level: minimal`.

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/battle/battle_core_test.gd` — at `qa.level: minimal` this is
  advisory (waived), not blocking, but still the expected test location.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/go-back-to-your-planet/story-002-bureaucratia.md`, `production/epics/go-back-to-your-planet/story-003-squad-specials.md`
