# Story 032: an alien faction with no boss lighting preset fails boot, never the fight

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-005`, `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `ContentBootstrap.run()` builds `PresentationValidators` and registers `boss_profile_exists` for alien `faction` records; a missing `boss_<faction>` preset is a boot Content Error, and only a debug run that skipped validation reaches a boss fight that stays in Battle light, logging one error.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Boot validation itself uses no post-cutoff API — it is a registration against ADR-0004's `register_record_validator`. The HIGH risk carries from ADR-0005's rendering domain generally; this story's own surface (a validator function and its boot-time invocation) needs no engine verification beyond the existing ADR-0004 pattern.

**Control Manifest Rules (this layer)**:
- Required: "Boot validation registers `PresentationValidators`: `sprite_set_exists`, `boss_profile_exists`, `required_animations`, `impact_frame`/`land_frame`, `intro` length vs `boss_hold`, no duplicate move-animation names, `PresentationConfig` load rules, `LightingProfile` rules, every flash source declaration" (Clocks and layering, ADR-0005 §7–§8, §11).
- Forbidden: no Core Forbidden entry names a specific bypass; the debug-only skip path is explicitly sanctioned by the AC itself (quoted below), not a violation.
- Guardrail: n/a — boot validation runs once, outside any frame-time budget.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-28 [I]** (P-06) GIVEN an alien Faction record with no `boss_<faction>` lighting preset, THEN boot ends in Content Error. GIVEN a debug run that skipped validation, THEN the boss fight stays in Battle light, the logger receives one error, and the fight completes.

---

## Implementation Notes

*Derived from ADR-0005 Decision §9 (Boot validation) and §3 (Profile requests):*

- `boss_profile_exists` is a record validator for every alien `faction` record, registered through ADR-0004's `register_record_validator`: it checks that `boss_<faction>` resolves in the `LightingProfile` table and fails boot with a Content Error naming the faction when it does not.
- The debug-skip path is reached only when boot validation itself was bypassed (a developer debug flag, not a player-reachable state): `stage.request_profile(&"boss_<faction>", …)` resolves against the stage's profile resolver (ADR-0005 §3), which returns `null` for an unknown ID — this **logs one error** and **leaves the light unchanged** (i.e. the stage stays on its already-applied `battle` entry profile), rather than crashing or defaulting to some other preset.
- The fight must still complete on this path — the missing boss light must never block the reveal gate, the takeover hold, or any beat; it is purely a lighting fallback, not a gameplay failure.
- This story's fixture is a `Faction` record with a deliberately absent `boss_<faction>` key in the profile table; the boot-side half of the test asserts the Content Error, and the debug-skip half asserts the logged error plus the unchanged light, as two separate test cases.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-034-unknown-sprite-set-id-fails-boot.md`: the parallel `sprite_set_exists` validator for Character/Enemy records.
- `story-038-boss-takeover-faction-parity.md`: the capture-measured correctness of a *present* boss preset's swatch.
- The general `PresentationConfig`/`LightingProfile` load-rule validators (covered incidentally by every story that touches boot, owned collectively by the migration, not one AC).

---

## Files

- `src/presentation/presentation_director.gd`
- `data/presentation/presentation_validators.gd`
- `tests/integration/presentation/boss_profile_exists_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/boss_profile_exists_test.gd` OR playtest doc

**Status**: [x] `tests/integration/presentation/boss_profile_exists_test.gd` (4 cases) passes (2026-10-31). Validator in `src/presentation/presentation_validators.gd` (the story names `data/presentation/`), registered by `ContentBootstrap.run()` against `<data_root>/presentation/profiles`

---

## Dependencies

- Depends on: ADR-0004's `register_record_validator` (Accepted, implementation status not tracked by this epic); boss stages and faction content (not yet authored)
- Unlocks: None
