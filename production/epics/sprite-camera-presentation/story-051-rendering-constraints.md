# Story 051: Rendering constraints are pinned at the project level

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-017`, `TR-presentation-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §10 pins the 3D render scale, anti-aliasing, HDR output and the Vulkan backend with both fallbacks off; §7 makes `mode_time` the only clock a world shader may read, enforced by a lint that fails any `TIME` read under a mode-scene path.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Both `rendering_device/fallback_to_d3d12` and `fallback_to_opengl3` default to `true` on 4.7.2 (probed 2026-10-22) and must be set `false` explicitly, or the Vulkan pin is silently defeated. Screen-space AA (FXAA/SMAA) and TAA stay off project-wide; MSAA 3D stays at 2×. HDR output (new in 4.7) stays off. The lint must pass a UI shader outside `ModeHost` that reads `TIME` — only world shaders are forbidden it.

**Control Manifest Rules (this layer)**:
- Required: Screen-space AA and TAA off; MSAA 3D 2×; HDR output off; 3D render scale 1.0, no upscaler (ADR-0005 §10)
- Required: Backend pinned to Vulkan on every target, both fallback settings explicitly `false` (ADR-0005 §10)
- Forbidden: `AreaLight3D`, HDR output, FXAA, SMAA, TAA, an upscaler, or a render scale below 1.0 without an amendment to ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-47 [L]** (P-06) (rendering constraints)
  - **Project settings:**
    - a 3D render scale of exactly 1.0, with no upscaler;
    - HDR output off;
    - screen-space AA and TAA off;
    - the rendering backend pinned to the one ADR-0005 names.
  - **Presets:** every lighting preset has glow bloom 0 and its own glow threshold.
  - **The world-shader lint** fails three fixtures under a mode-scene path:
    - a shader file reading `TIME`;
    - a scene with embedded shader code reading `TIME`;
    - a visual shader with a Time node.

    It passes a UI shader outside `ModeHost` that reads `TIME`.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This story has two independent halves: a project-settings check (§10) and a static lint over every shipped `LightingProfile` plus every shader, scene and visual shader under a mode-scene path (§5, §7, §9). Neither half adds new runtime rendering code; both are verification plus the `project.godot` keys they check.

- `project.godot` must set `rendering/rendering_device/driver.windows = "vulkan"` and `.linuxbsd = "vulkan"`, and explicitly set both `fallback_to_d3d12` and `fallback_to_opengl3` to `false` (§10).
- Screen-space AA and TAA off; MSAA 3D at 2×; HDR output off; 3D render scale 1.0, no upscaler (§10).
- Every `LightingProfile.tres` must validate glow bloom `0` and a present `glow_threshold` (§5, §9) — this story's test reads the shipped profiles, it does not author them.
- The world-shader lint walks every shader file, every scene's embedded shader code, and every visual shader's node graph under a mode-scene path, failing on any `TIME` read; it must explicitly pass a `ModeHost`-external UI shader that reads `TIME` (§7).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-069-nothing-compiles-in-play.md`: measures that nothing recompiles a pipeline once these settings are in place — a separate, runtime assertion
- `story-002-capture-tool.md` (writer A): the capture tool these same settings are checked against for [C] stories

---

## Files

- `project.godot`
- `tests/unit/presentation/rendering_constraints_test.gd`
- `tests/unit/presentation/world_shader_time_lint_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/rendering_constraints_test.gd` — must exist and pass
- `tests/unit/presentation/world_shader_time_lint_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/rendering_constraints_test.gd` (5 cases) and `tests/unit/presentation/world_shader_time_lint_test.gd` (7 cases) pass (2026-10-31). Lint: `src/presentation/world_shader_time_lint.gd`

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md` (the windowed spike confirms the backend resolves to Vulkan and records the fallback settings' actual defaults on 4.7.2)
- Unlocks: `production/epics/sprite-camera-presentation/story-069-nothing-compiles-in-play.md` (needs these settings pinned correctly before it can measure the compile contract)
