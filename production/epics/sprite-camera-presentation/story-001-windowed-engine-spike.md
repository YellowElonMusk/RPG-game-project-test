# Story 001: Windowed engine spike settles sprite-shader and camera verification on 4.7.2

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-001`, `TR-presentation-002`, `TR-presentation-003`, `TR-presentation-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `CharacterSprite`'s shader owns projection, depth and lighting via a clip-space quad on the upright card; the battle camera is level and shift-lens on `PROJECTION_FRUSTUM`; nothing may compile a rendering pipeline in play after Boot warm-up.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Rendering changed post-cutoff in 4.5 (Shader Baker, SMAA), 4.6 (glow order, D3D12 default) and 4.7 (`AreaLight3D`, HDR output). Verification items (10) and (11) — the clip-space quad's pixel-exactness and the `frustum_offset` sign/units — are already VERIFIED (2026-10-22). This spike closes the five still open: (12) `ambient_light_disabled` plus key-only actor lighting; (13) manual `AnimatedSprite3D` frame stepping rendered in a windowed run; (14) flip-based mirroring in the shader; (15) the glow-input hook ahead of tonemapping; (16) which lighting parameters compile a pipeline, measured on the `RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_*` counters.

**Control Manifest Rules (this layer)**:
- Required: Battle camera is `PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` ALWAYS; its only per-frame change is `frustum_offset` (lens shift + punch) — source: ADR-0005
- Forbidden: Never use `keep_aspect = KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2 (CPU/GPU projections disagree, probed) — source: ADR-0005
- Guardrail: Frame time p99 ≤ 16.6 ms, worst ≤ 33 ms on a GTX 1080-class desktop at 1920×1080 and on Steam Deck at 1280×800 — source: ADR-0005, `project.yaml`

---

## Acceptance Criteria

*From ADR-0005's Migration Plan Step 1 and Validation Criteria ("Step 1 evidence"), scoped to this story:*

- [ ] One `CharacterSprite`-equivalent with placeholder art renders lit, nearest-filtered, alpha-cut sprite pixels inside a small lit diorama, under a level shift-lens battle camera, a pitched overworld camera, a sky card, and the `battle`, `boss_*` and `camp` profiles
- [ ] Verification item (12): `ambient_light_disabled` plus key-only lighting on actors is confirmed in a windowed run
- [ ] Verification item (13): manual frame stepping of `AnimatedSprite3D` (its own playback stopped) renders the stepped frame correctly in a windowed run
- [ ] Verification item (14): flip-based mirroring done in the shader is confirmed
- [ ] Verification item (15): reading the glow input before tonemapping (the compositor hook) for the capture tool is confirmed, or recorded as failed
- [ ] Verification item (16): which lighting parameters compile a rendering pipeline is measured with the `RENDERING_INFO_PIPELINE_COMPILATIONS_*` counters, and the confirmed compiling-parameter list is published into ADR-0005 §11 (Step 1b)
- [ ] The `frustum_offset` sign, re-measured against `battle_framing`'s `y_h` at 16:9 and 16:10, is published into ADR-0005 §6 (Step 1b)
- [ ] `battle_fov`, `h_cam`, `horizon_frac`, slot depths and `humanoid_height_px` are set
- [ ] The spike runs on a Steam Deck as a native Linux export at 1280×800, recording frame time (p99, worst) with MSAA 2×, DOF and glow on, peak RAM/VRAM, the 16:10 framing, and the Vulkan-failure alert text and fallback setting names
- [ ] Retained screenshots (battle, one boss takeover, camp; near and far rows; a pitched overworld sprite against a wall) are saved to `production/qa/evidence/` with lead sign-off

---

## Implementation Notes

*Derived from ADR-0005 Migration Plan and Decision §§1–2, 6, 11:*

- Lives in `prototypes/sprite_camera_spike/`, **not** `src/` — this is a throwaway technical spike, not production code (the TD-ADR review required this explicitly).
- The clip-space quad (§2) and `frustum_offset` (§6, items 10–11) are already verified — do not re-derive them, just exercise them under real rendering and record what happens.
- Items (12)–(16) are exactly what this spike exists to close; each needs an observed, not assumed, result recorded back into ADR-0005.
- §11's "parameters believed to change a pipeline" list (glow/fog/SSAO/SSIL/SSR, DOF near/far enabled, tonemapper mode, a light's `shadow_enabled` and type, material features, MSAA level, shadow atlas size) is the working hypothesis the counters must confirm or correct, from an emptied engine Vulkan pipeline cache and `.godot/shader_cache/`.
- The Steam Deck run is binding: it must be a native Linux export (Godot's `Linux` preset, x86_64), never the Windows build under Proton (§10).
- Record the engine's own Vulkan-failure alert text (shown before any script runs) verbatim; it cannot be customised from GDScript.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (`production/epics/sprite-camera-presentation/story-002-capture-tool.md`): the capture tool itself, built from this spike's confirmed settings
- Stories 003–026: the production `src/presentation/` build (ADR-0005 Migration Step 3), which happens after this spike and after ADR-0004's implementation

---

## Files

- `prototypes/sprite_camera_spike/` (scene, scripts, placeholder art — throwaway)
- `docs/architecture/adr-0005-sprite-camera-presentation.md` (§6 and §11 updated in place, Step 1b)
- `production/qa/evidence/sprite-camera-spike/` (retained screenshots)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/sprite-camera-spike/` + sign-off in `production/qa/evidence/sprite-camera-spike-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/sprite-camera-presentation/story-002-capture-tool.md`, and every story 003–026 that depends on shader or stage rendering behaviour
