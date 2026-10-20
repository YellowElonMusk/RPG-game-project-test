# Story 005: Battle HUD — bars, rule banner, floating numbers, tooltips

> **Epic**: Go back to your planet!
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — "Battle HUD: HP/MP bars, a faction rule
banner, floating numbers, and tooltips that explain the rule."

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (post-cutoff version per `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

**Reference**: `prototypes/battle-concept/battle.gd` builds a working version of
every element this story needs (HP/MP bars, a rule banner with a countdown, floating
damage/heal numbers, hover tooltips) — screenshots are in
`prototypes/battle-concept/REPORT.md`. Throwaway code; do not import it, but match
its proven layout and behavior unless design changes it.

---

## Acceptance Criteria

*From the brief's MVP feature 6:*

- [ ] Every squad member's current and max HP are shown as a bar.
- [ ] Every squad member's current and max MP are shown as a bar.
- [ ] A banner shows the active faction's rule (e.g. Bureaucratia's permit
      countdown, or MegaCorp's billing) and updates as that rule's state changes
      (e.g. round count, or granted/lifted).
- [ ] Damage and heal amounts appear as floating numbers near the affected
      combatant when they happen.
- [ ] Hovering a card or relevant control shows a tooltip explaining the current
      rule in plain language.
- [ ] The HUD correctly reflects both factions' rules (Bureaucratia's permit ban
      and MegaCorp's billing/suspension), not just one.
- [ ] A knocked-out combatant's card visibly differs from a living one (at minimum,
      it is clearly marked or dimmed).

---

## Implementation Notes

*No ADR at this tier — implement from the Acceptance Criteria and the prototype reference above.*

- The prototype (`prototypes/battle-concept/battle.gd`) is a working reference for
  every element in this story's scope — its bar styling, banner countdown text, and
  floating-number tween behavior can be used as a starting point, rewritten as
  production code rather than copied.
- This story is the first one that must render against both Story 002
  (Bureaucratia) and Story 004 (MegaCorp) rule states — build the banner/tooltip
  text as data the faction rule exposes, not hardcoded per-faction UI branches.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–004: the battle logic this HUD displays — this story does not change
  any rule, only presents it.
- Story 006: the chapter-level UI (e.g. moving from one fight to the next) is not
  this story's battle-internal HUD.
- Final art direction (pixel sprites, 3D dioramas) — Out of scope in the brief for
  this whole MVP; placeholder panels are expected here too.

---

## Files

- `src/battle/ui/battle_hud.gd`
- `src/battle/ui/battle_hud.tscn`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- A retained screenshot of each screen state this story touches (normal battle, permit-pending banner, permit-granted banner, MegaCorp billing banner, a knocked-out combatant) in `production/qa/evidence/`.
- Sign-off in `production/qa/evidence/battle-hud-evidence.md`.
- **Not waived at `qa.level: minimal`** — UI evidence is never advisory.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-001-battle-core.md`, `production/epics/go-back-to-your-planet/story-002-bureaucratia.md`, `production/epics/go-back-to-your-planet/story-004-megacorp.md`
- Unlocks: `production/epics/go-back-to-your-planet/story-006-chapter-flow.md`
