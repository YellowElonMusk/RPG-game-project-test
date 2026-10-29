# Story 003: Actors are lit only by their key and rim light, never ambient, fill or set light

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Actors use `render_mode ambient_light_disabled`; only lights whose cull mask includes `ACTORS` light them (the `KeyLight` and tagged practicals), and every `boss_<faction>` profile's actor key and rim colors must equal the Battle preset's.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `render_mode ambient_light_disabled` and `light_cull_mask` are NOT SOURCEABLE in the engine reference (pre-cutoff training gap). Verification item (5) — `light_cull_mask` isolating the key light to actors and the set light to the set — was PASS in the original windowed spike; item (12) — `ambient_light_disabled` plus key-only lighting on actors — is closed by story 001.

**Control Manifest Rules (this layer)**:
- Required: Actors use `render_mode ambient_light_disabled`. Only lights whose cull mask includes `ACTORS` light them — source: ADR-0005
- Required: Light rig: `KeyLight` (cull `ACTORS`, no shadows), `SetLight` (cull `SET`, the ONLY shadow caster), `FillLight` (cull `SET`, no shadows) — source: ADR-0005
- Forbidden: The rim is added only on the rim texel ring; never on the outline — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-1 [L]** (P-06) In every shipped lighting preset:
  - the actor key lights only actors, and the set and fill lights only the set;
  - the actor material takes no ambient light, and every actor's rim strength is above 0;
  - every `boss_<faction>` preset's actor key and rim colors equal the Battle preset's.

---

## Implementation Notes

*Derived from ADR-0005 Decision §2 and §3:*

- The shader is shaded, with `render_mode ambient_light_disabled`, so environment ambient never reaches an actor; only the `KeyLight` and stage practicals tagged `actor_lighting` (cull mask including `ACTORS`) light it.
- The light rig per `DioramaStage`: `KeyLight` (DirectionalLight3D, cull `ACTORS`, no shadows), `SetLight` (DirectionalLight3D, cull `SET`, the only shadow caster), `FillLight` (DirectionalLight3D, cull `SET`, no shadows); the set's key:fill ratio is `SetLight` energy over `FillLight` energy.
- `LightingProfile` holds the actor key's color, energy and angle (it casts no shadow, so a profile may aim it); the rim's color and strength separately.
- A `boss_<faction>` profile carries the faction's dusk flood swatch for the sky/set/fill, but its actor key and rim colors must still equal the Battle preset's, by construction — actors never take the flood tint.
- Every value comes from `LightingProfile`/`PresentationConfig` `.tres` data, never literals.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 019 (`production/epics/sprite-camera-presentation/story-019-squad-rim-and-outline-stay-constant.md`): rim/outline color equality across every preset and faction-color distance checks
- Story 020 (`production/epics/sprite-camera-presentation/story-020-one-blob-shadow-per-actor-set-light-only-caster.md`): shadow casting and blob shadows

---

## Files

- `data/presentation/profiles/*.tres`
- `src/presentation/lighting_profile.gd`
- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/lighting_profile_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/lighting_profile_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/lighting_profile_test.gd` — 2/2 passing; full suite 637/637 green

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-019-squad-rim-and-outline-stay-constant.md`, `production/epics/sprite-camera-presentation/story-020-one-blob-shadow-per-actor-set-light-only-caster.md`

---

## Completion Notes

- `src/presentation/lighting_profile.gd`: `LightingProfile extends Resource`, data only, matching ADR-0005 §5's abridged Key Interfaces block field-for-field (lights, sky card, tone/glow, DOF, §14 travel light, shadow, blend). No validation methods here — that's `PresentationValidators`' job (§9, Story 061).
- `src/presentation/diorama_stage.gd`: `DioramaStage extends Node3D`, trimmed to this AC's scope (key/set/fill light rig + profile pipeline only — camera, sky card, `active_diorama_stage` group membership, `set_ambient_paused`/`set_punch_offset_px` are later stories', per the build brief). `_ready()` pins `key_light` to `light_cull_mask = LAYER_ACTORS` with shadows off, `set_light`/`fill_light` to `LAYER_SET` (`set_light` the only shadow caster), and the environment's `ambient_light_energy` to 0 — all structural, never from profile data. `bind_profiles()`/`request_profile()`/`apply_profile()` match the ADR signatures; `apply_profile()` sets final light/rim values immediately (`TODO(sprite-camera-presentation)`: the tween/clock blend over `blend_time` is Story 009/026's scope).
- `data/presentation/profiles/{title,overworld,battle,boss_bureaucratia,boss_megacorp,camp,victory,defeat}.tres`: the 8 MVP presets (ADR-0005 §5). `boss_bureaucratia` and `boss_megacorp` copy `battle`'s `key_color`/`key_energy`/`key_rotation_deg`/`rim_color`/`rim_strength` exactly (actors never take the faction flood tint) and tint only `set_color`/`fill_color`/the sky fields per faction. Every preset's `rim_strength` is above 0 and `glow_bloom` is 0. Actual color/energy/DOF/tone values are placeholder MVP art direction, not yet lit by `godot-shader-specialist` or reviewed by a creative-director — expect retuning.
- `tests/unit/presentation/lighting_profile_test.gd`: discovers presets via `DirAccess.get_files_at()` (no hardcoded ID list), builds a `DioramaStage` with real `DirectionalLight3D`/`WorldEnvironment` children and calls `stage._ready()` directly (no live `SceneTree` needed for this AC). One test applies every preset and checks cull masks, shadow casters, ambient and `rim_strength > 0`; a second checks every `boss_<faction>` preset's key/rim colors against `battle`'s.
- Deviations: (1) the actor shader (`render_mode ambient_light_disabled`) and `CharacterSprite.cast_shadow = OFF` are not touched here — `character_sprite.gd` isn't in this story's Files list, no `sprite_actor.gdshader` exists yet in production, and shader authorship is `godot-shader-specialist`'s domain; AC-1's "actor material takes no ambient light" is covered here via the stage's `ambient_light_energy = 0.0` invariant instead, which is the data-driven half of that guarantee. (2) `apply_profile()` applies instantly rather than blending — in scope for Story 009/026, flagged with a `TODO`.
- Verified: targeted test 2/2 passing with 0 orphans; full suite 637/637 green after `--import` (`$TEMP/scp003_full.log`).

**Test Evidence Status**: `tests/unit/presentation/lighting_profile_test.gd` — 2/2 passing. Full suite: 637/637 green (`$TEMP/scp003_full.log`).
