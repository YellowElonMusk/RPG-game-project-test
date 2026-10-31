# Story 019: The squad's rim and outline colors stay constant, and no non-boss light matches a faction color

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-003`, `TR-presentation-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `LightingProfile` fixes the squad's rim color and outline ink across every state; outside `boss_*`/`occupied_*` presets no light color may sit within ΔE 10 of a faction's signature color, and shadow color must stay at least ΔE 10 away in every preset — faction color belongs only to the boss takeover, by data construction.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is a data-validation story over shipped `LightingProfile` `.tres` resources, not a rendering behaviour.

**Control Manifest Rules (this layer)**:
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`). Every lighting/FOV/camera/texel/timing value comes from them, never literals — source: ADR-0005
- Forbidden: Faction colour only on the sky, set and fill during that faction's boss takeover; never on actors, neutral states, fades or UI (rule 11) — source: ADR-0005, EPIC TR-presentation-024

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-16 [L]** (P-06) GIVEN every lighting preset, THEN the squad's rim color and outline ink equal the presentation config's in every state. In every preset that is not `boss_*` or `occupied_*`, no light color is within ΔE 10 of any faction's signature color. In every preset, the shadow color is at least ΔE 10 from every faction's signature color.

---

## Implementation Notes

*Derived from ADR-0005 Decision §5:*

- `LightingProfile`'s `rim_color`/`rim_strength` fields are read-only truth for this check; the squad's actual rendered rim must equal them in every shipped preset, boss presets included (story 003 already requires boss presets to match the Battle preset's key/rim).
- Outline Ink is the fixed art-bible constant (`#1A1418`, matched within a small tolerance, §2); it never varies by preset.
- The ΔE 10 distance check runs against every faction's signature color across every non-boss, non-occupied preset's light colors and every preset's `shadow_color` — this is a boot-time or test-time data audit over the shipped `.tres` files, not a runtime behaviour.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003 (`production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`): which lights may reach actors at all
- Story 020 (`production/epics/sprite-camera-presentation/story-020-one-blob-shadow-per-actor-set-light-only-caster.md`): shadow casting mechanics

---

## Files

- `src/presentation/lighting_profile.gd`
- `data/presentation/profiles/*.tres`
- `tests/unit/presentation/lighting_profile_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/lighting_profile_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/lighting_profile_test.gd` (9 cases) + `tests/unit/presentation/color_difference_test.gd` (7 cases) pass; full suite 1790/1790, exit 0, 0 orphans (2026-10-31)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`
- Unlocks: None
