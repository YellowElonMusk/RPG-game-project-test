# Story 001: Windowed engine spike settles sprite-shader and camera verification on 4.7.2

> **Epic**: Sprite & Camera Presentation
> **Status**: In Progress (2026-10-29): partial spike: Steam Deck run, lead sign-off and the empty-cache pipeline-counter run (item 16) owed; item 15 (glow input) recorded FAIL
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

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

**Status**: [~] Partial: 13 windowed screenshots retained in `production/qa/evidence/story-001-windowed-engine-spike/` (spike 2026-10-29); lead sign-off and the Steam Deck run are owed

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/sprite-camera-presentation/story-002-capture-tool.md`, and every story 003–026 that depends on shader or stage rendering behaviour

---

## Completion Notes

*Spike 2026-10-29: Windows 11, RTX 4080 SUPER, Vulkan 1.4.357, Godot 4.7.2, windowed at 1280×720 (16:10 at 1280×800). Code in `prototypes/sprite_camera_spike/`; run with `-s res://prototypes/sprite_camera_spike/spike_main.gd`. Evidence in `production/qa/evidence/story-001-windowed-engine-spike/`. Results are written back into ADR-0005 (items 12–16, §6, §11), each marked "(spike 2026-10-29)".*

| Criterion | Result | Evidence / observation |
|---|---|---|
| Diorama, placeholder sprite, battle and overworld cameras, sky card, profiles | **PARTIAL** | `battle.png`, `boss_takeover.png`, `camp.png`, `overworld_pitched_wall.png`. The sprites are nearest-filtered, alpha-cut and lit. The boss and camp profiles visibly retint the actors. Gaps: the wall hides the sky card except for 2–3 px strips at the frame edges. The sprite is a plain upright `AnimatedSprite3D` card, not §2's clip-space quad, so it goes edge-on under the pitched camera and scales with depth. Only `boss_bureaucratia` was shot; `boss_megacorp` was not. |
| (12) ambient disabled + key-only | **PASS** | `ambient_key_only_lit.png` / `ambient_key_only_dark.png`: with KeyLight hidden the actors render pure black and the set stays lit. Side finding: actors cast SetLight shadows (visible on the floor), so §2's `cast_shadow = OFF` is needed. |
| (13) manual frame stepping | **PASS** | `frame_step_0.png` / `frame_step_1.png`: the yellow frame-1 block appears only on the stepped sprite. |
| (14) shader flip mirroring | **PASS** | `flip_normal.png` / `flip_mirrored.png`: the red marker moves from the right side to the left. |
| (15) glow input before tonemapping | **FAIL** (recorded) | Run log: no `EffectCallbackType` after `POST_TRANSPARENT` (4), and no glow texture found via `has_texture()`. Only the pre-glow color is readable. |
| (16) pipeline counters | **PARTIAL / OWED** | Run log: energy, color and glow-intensity changes added 0 compiles. `glow_enabled` and `shadow_enabled` toggles also added 0, on a warm cache (deleting the cache was not permitted). The empty-cache run and the rest of the list are owed. |
| `frustum_offset` sign at 16:9 / 16:10 | **PASS** | +0.1·h_near moved the image down by 72 px (720p) and 80 px (800p), exactly 0.1·H. `battle_16x10.png`. |
| Knobs set | **PASS (spike values)** | battle_fov 32°, near 0.3, h_cam 1.0, horizon_frac 0.42, slot depths 4/6/8.5, humanoid_height_px 120 (target only: the plain card does not enforce T). Not final balance. |
| Steam Deck native Linux export | **OWED** | No Steam Deck on this PC. |
| Retained screenshots + lead sign-off | **PARTIAL / OWED** | Screenshots retained (`near_far_rows.png` included); lead sign-off owed. |

- Status synced 2026-10-30 from commit 5c517c0; owed: partial spike: Steam Deck run, lead sign-off and the empty-cache pipeline-counter run (item 16) owed; item 15 (glow input) recorded FAIL.
