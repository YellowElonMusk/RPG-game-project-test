# Story 062: A boss sprite set with no front intro fails boot

> **Epic**: Sprite & Camera Presentation
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §9's `required_animations` validator checks rule 10's table, which requires `intro` for boss sprite sets; an encounter naming a boss whose set has no `front` `intro` must end boot in a content error naming the set.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is a focused extension of the §9 `required_animations` validator for the boss-specific `intro` requirement, scoped to the `front` facing (bosses always face front for their takeover).

**Control Manifest Rules (this layer)**:
- Required: `required_animations` validates rule 10's table, with `victory` required for squad sets and `intro` required for boss sets (ADR-0005 §9)
- Required: A missing boss preset, or missing required animation, is a boot content error naming the record/set (ADR-0005 §9)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-57 [L]** (P-06) (boss intro required) GIVEN an encounter naming a boss whose sprite set has no `front` `intro`, THEN boot ends in a content error naming the set.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This is a narrow extension of the `required_animations` boot validator (§9): for any encounter record naming an `is_boss` enemy, the validator resolves that enemy's `sprite_set_id` and checks that a `front` `intro` animation exists in the set, failing with a content error naming the set if it doesn't.
- Only the `front` facing is checked — bosses face front for the takeover and `intro`, so `back_intro` is not required.
- This reuses the same `register_record_validator` registration path as every other §9 validator; no separate boot phase is introduced.
- The error message names the sprite set, not the encounter, so the same content error is produced however many encounters reference that boss.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-066-impact-and-landing-frame-data-required.md`: `impact_frame`/`land_frame`/`intro`-duration validation for the same sprite sets
- `story-061-presentation-config-load-validation.md`: `PresentationConfig`'s own numeric load rules

---

## Files

- `src/presentation/presentation_validators.gd`
- `tests/unit/presentation/boss_intro_required_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/boss_intro_required_test.gd` — must exist and pass

**Status**: [x] Created — passing (suite 1690/1690)

---

## Dependencies

- Depends on: None
- Unlocks: None
