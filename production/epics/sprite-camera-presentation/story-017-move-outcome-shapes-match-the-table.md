# Story 017: Each shipped move resolves to its documented pose, reactions, numbers and punch shape

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership (primary), ADR-0005: Sprite & Camera Presentation (secondary)
**ADR Decision Summary**: `BattleReplayController` maps every outcome shape to an actor action and per-combatant reactions, with no move ever playing the wrong pose, per the GDD's documented table of move → pose/reactions/numbers/punch.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0006 itself is LOW risk. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: Core never imports Feature: `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController` — source: ADR-0005
- Forbidden: Never let a non-resolving outcome (no state change) show a number — "no number anywhere reads '0'" — source: GDD rule / AC-14b

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-14b [L]** (P-04) (outcome shapes) GIVEN each shipped move resolved by a real, seeded `BattleCore`, THEN:

  | Move | Actor pose | Reactions | Numbers | Punch |
  |---|---|---|---|---|
  | Attack (damaging) | `attack` | target `hit`, or `knockout` if it fell | one, over the target | yes |
  | Attack (0 damage, fixture) | `attack` | target `hit` | none | no |
  | Defend | `defend` | none | none | no |
  | Family Meal (3 living members including the healer, one at full HP) | its move-specific animation or `attack` | `heal` (or no change in pose) on each healed member other than the healer | one per healed member, the healer included; none for the one at full HP | no |
  | Appetizers (single heal) | its move-specific animation or `attack` | target `heal` (or no change in pose) | one, over the target | no |
  | Home Run (direct damage) | its move-specific animation or `attack` | target `hit`, or `knockout` if it fell | one, over the target | yes |
  | Speak to the Manager | its move-specific animation or `attack` | target `status`, or `hit` when the set has no `status` art | none | no |
  | Viral Stunt | its move-specific animation or `attack` | target `status`, or `hit` when the set has no `status` art | none | no |

  No number anywhere reads "0".

---

## Implementation Notes

*Derived from ADR-0006 Requirements ("Map every outcome shape to an actor action and per-combatant reactions, with no move ever playing the wrong pose") and ADR-0005 §9 (required animations per set):*

- The beat plan built per outcome selects the actor's pose from the move's category, falling back to `attack` when the move has no dedicated animation.
- A reactor's pose falls back from its move-specific reaction to `hit` only when the set has no `status` art for that reaction, per rule 10's fallback (ADR-0005 §9 boot validation; story 018 enforces the boot-time guarantee that this fallback is always available).
- A 0-damage Attack and a fixture 0-damage case both show no number — this is a special case the beat plan must detect, not leave to the HUD to suppress.
- `src/battle/beat_plan.gd` is immutable after construction (ADR-0006 Key Interfaces), so the table's mapping must be decided once, at outcome-to-beat-plan translation time.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018 (`production/epics/sprite-camera-presentation/story-018-boot-validation-of-sprite-set-animations.md`): the boot-time guarantee that every required/fallback animation exists

---

## Files

- `src/battle/beat_plan.gd`
- `data/battle/moves/*`
- `tests/unit/presentation/outcome_shape_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/outcome_shape_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet), `production/epics/sprite-camera-presentation/story-016-replay-never-mutates-battlecore.md`
- Unlocks: None
