# Story 034: an unknown sprite_set_id fails boot; the checkerboard placeholder reaches Title

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Boot validation registers `sprite_set_exists` for `character` and `enemy` records; `sprite_placeholder` maps to a checkerboard rather than failing, and the enemy validator takes effect after ADR-0001's enemy migration.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's general HIGH rendering risk; the validator itself (a dictionary lookup against the sprite-set table) introduces no post-cutoff API and needs no engine verification beyond ADR-0004's existing boot pattern.

**Control Manifest Rules (this layer)**:
- Required: "Boot validation registers `PresentationValidators`: `sprite_set_exists`, `boss_profile_exists`, `required_animations`..." (Clocks and layering, ADR-0005 §7–§8, §11).
- Required: "Records reference art by **asset ID**; presentation maps IDs to files" (ADR-0001 constraint, carried into ADR-0005 §5 "the sprite-set table, as untyped `Dictionary`s from an ID to a `res://` path `String`").
- Forbidden: no Core Forbidden entry applies; the placeholder path is an explicit, sanctioned fallback (quoted in Implementation Notes), not a bypass.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-30 [I]** (P-06) (Content Data) GIVEN a Character record with an unknown `sprite_set_id`, THEN boot ends in Content Error. GIVEN the checkerboard placeholder ID, THEN boot reaches Title.

---

## Implementation Notes

*Derived from ADR-0005 Decision §9 (Boot validation):*

- `sprite_set_exists` checks every `character` and `enemy` record's `sprite_set_id` against `PresentationConfig`'s sprite-set table (§5: an untyped `Dictionary` from ID to a `res://` path `String`; the loader rejects non-`String` keys or values). An ID absent from the table is a Content Error naming the record.
- `sprite_placeholder` is a **known, reserved ID** that maps to a checkerboard sprite set in the table, not an error — it exists so a Character record with art not yet authored can still boot and reach Title, which is this AC's second clause.
- The enemy half of `sprite_set_exists` "takes effect after ADR-0001's enemy migration" — if that migration has not landed when this story is implemented, the enemy-record assertions in this test are written against the Character-record path only, and a TODO documents the gap rather than silently skipping enemy coverage.
- This is purely a boot-time content check: no rendering, no `CharacterSprite` instantiation — the test can run with a fixture `PresentationConfig` and fixture Character/Enemy records, entirely headless.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-032-missing-boss-preset-fails-boot.md`: the parallel `boss_profile_exists` validator for Faction records.
- `story-046-no-two-actor-slots-share-a-depth.md`: battle-stage formation validation (a different validator entirely).
- Actually instantiating `CharacterSprite` from a resolved `sprite_set_id` (ADR-0005 §1, a separate migration-plan step).

---

## Files

- `data/presentation/presentation_validators.gd`
- `tests/integration/presentation/sprite_set_exists_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/sprite_set_exists_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0004's `register_record_validator`; ADR-0001's enemy migration (for the enemy half of the validator)
- Unlocks: None
