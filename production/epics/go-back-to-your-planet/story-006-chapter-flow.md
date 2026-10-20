# Story 006: Chapter flow — fight chain and boss, both planets

> **Epic**: Go back to your planet!
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — "A linear chapter per planet: 3 fights,
then the boss. No free roaming." Also ties to the brief's Player goal: "beat both
faction bosses: Bureaucratia's Supervisor and MegaCorp's CEO."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: None — the prototype tested one battle only, not a chapter. This
story is new integration work.

---

## Acceptance Criteria

*From the brief's MVP feature 5 and the Player goal & fail state:*

- [ ] Starting the Bureaucratia chapter runs exactly 3 regular fights (Clerks) in
      sequence, followed by the Supervisor boss fight.
- [ ] Starting the MegaCorp chapter runs exactly 3 regular fights (security drones
      and/or middle managers) in sequence, followed by the CEO boss fight.
- [ ] The squad's HP and MP carry over between fights within a chapter (no full
      heal between fights, consistent with no leveling/items/shops in this MVP).
- [ ] Losing any fight in a chapter retries that single fight from its start, per
      the brief's fail state — it does not restart the whole chapter.
- [ ] Defeating a chapter's boss ends that chapter; the game records both chapters
      as complete once both bosses are beaten, satisfying the brief's Player goal.
- [ ] There is no free-roaming or branching between fights — the sequence is fixed,
      per the brief.

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria above.*

- This story is the integration layer that calls Story 001's battle core
  repeatedly with Story 002's or Story 004's faction rule active, and Story 005's
  HUD for each fight — it should not reimplement any battle logic itself.
- HP/MP carryover between fights (no full heal) is stated directly in the brief's
  Out of Scope ("no... leveling, items, shops") combined with the Core loop's
  chain structure; if this reading is wrong, confirm with the user before changing it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–005: all battle-internal logic and presentation.
- Anything in the brief's Out of Scope: overworld exploration, recruiting, loyalty,
  faction reputation/endings, leveling, items, shops, saving, menus beyond the
  battle.

---

## Files

- `src/chapters/chapter_flow.gd`
- `tests/integration/chapter_flow/chapter_flow_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/chapter_flow/chapter_flow_test.gd` OR a playtest doc —
  advisory (waived) at `qa.level: minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-002-bureaucratia.md`, `production/epics/go-back-to-your-planet/story-004-megacorp.md`, `production/epics/go-back-to-your-planet/story-005-battle-hud.md`
- Unlocks: None
