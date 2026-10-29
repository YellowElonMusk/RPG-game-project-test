# Story 018: Missing required animations fail Boot; missing optional ones fall back with one warning

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `PresentationValidators`, registered through `ContentBootstrap.run()`, enforce `required_animations` per rule 10's table (including a squad set's `victory`); a missing required animation is a Content Error naming the set and animation, a missing optional one falls back with exactly one logged warning.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; depends on ADR-0004's `register_record_validator` (Accepted), which this story's validators plug into.

**Control Manifest Rules (this layer)**:
- Required: Boot validation registers `PresentationValidators`: `sprite_set_exists`, `boss_profile_exists`, `required_animations`, `impact_frame`/`land_frame`, `intro` length vs `boss_hold`, no duplicate move-animation names, `PresentationConfig` load rules, `LightingProfile` rules, every flash source declaration — source: ADR-0005
- Guardrail: Boot's warm-up stage adds a one-off cost at boot, measured in P-15 — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-15 [L]** (P-06) GIVEN a sprite set missing a required animation from rule 10's table in a facing it uses (including a squad set's `victory`), THEN boot ends in Content Error naming the set and animation. GIVEN a missing optional animation, THEN rule 10's fallback plays, the logger receives exactly one warning, and the battle completes. GIVEN a debug run that skipped validation and a `no_mirror` animation with no same-facing art, THEN the checkerboard placeholder plays, and the opposite facing is never mirrored.

---

## Implementation Notes

*Derived from ADR-0005 Decision §9:*

- `ContentBootstrap.run()` loads `PresentationConfig`, builds `PresentationValidators` from it, registers them, and returns the config for `PresentationDirector.setup()`.
- `required_animations` checks rule 10's table, `victory` required for squad sets and `intro` for boss sets included; a missing required animation in a facing the set actually uses is a Content Error naming both the set and the animation.
- A missing *optional* animation instead plays rule 10's fallback, logs exactly one warning, and the battle still completes — this must not be a hard failure.
- The debug path (validation skipped) is the only way the checkerboard placeholder and an unmirrored `no_mirror` fallback can appear together; this is deliberately a developer-only escape hatch, never production behaviour.
- `sprite_placeholder` maps to the checkerboard for `character`/`enemy` records with an unknown `sprite_set_id` (story 030 territory, out of this batch).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005 (`production/epics/sprite-camera-presentation/story-005-no-mirror-animations-use-authored-art.md`): the production (non-debug) mirroring path

---

## Files

- `src/presentation/presentation_validators.gd`
- `data/presentation/sprite_sets/*`
- `tests/unit/presentation/boot_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/boot_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`
- Unlocks: None
