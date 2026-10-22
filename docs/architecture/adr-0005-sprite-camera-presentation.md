# ADR-0005: Sprite & Camera Presentation — Constant-Scale Pixel Sprites in 3D Dioramas, a Level Shift-Lens Battle Camera, Data-Driven Lighting

## Status
Proposed

## Date
2026-10-21 (revision 2: 2026-10-22)

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist and technical-director (TD-ADR). Revision 2 applies the fifth `/design-review` of `design/gdd/sprite-camera-presentation.md` (NEEDS REVISION, 2026-10-22): its tracked list for this ADR, and creative-director rulings 4 (D1–D4) and 5.

> **Revision 2 (2026-10-22).** Revision 1 described a Y-locked billboard sized by a world-space `pixel_size`, actors casting `SetLight` shadows, a translation-only camera shake, an `Environment` sky, and no step that builds the capture tool. The GDD has moved past all of that. This revision makes these changes:
> - **Sprites:** a screen-aligned quad of constant integer texel size `T = H/360`, placed at the pixel-snapped projected foot anchor, with upright-card depth (§1, §2).
> - **Cameras:** a level, shift-lens battle camera on `PROJECTION_FRUSTUM`, with the hit-punch as extra lens shift (§6).
> - **Sky:** an unlit backdrop sky card, because the `Environment` sky doesn't follow the lens shift (§3).
> - **Actors:** a rim that excludes the outline, and actor lighting with no ambient (§2). Actors cast no shadows; a blob instead (§3).
> - **Rendering contract:** the measured compile contract with Boot warm-up (§11); the Vulkan pin (§10).
> - **Services:** a `GlobalUniformSink` (§4), and the `FlashGate` service (§12).
> - **Capture tool:** its build step, Migration Step 1c, with its own story (§13).
>
> Superseded text from revision 1 is not kept. Its Review History entry records what changed.

## Summary
Sprite & Camera Presentation needs a concrete Godot 4.7 way to render the art bible's look: pixel-art sprites lit inside low-poly 3D dioramas, under fixed cameras, with one lighting signature per game state. The GDD (revision 6) requires every sprite texel to be exactly `T × T` screen pixels at every depth, a level battle camera that frames the ground by lens shift, a dusk boss flood on a visible sky, and no shader compile in play. Decided:
- **Sprites** are `CharacterSprite` nodes (an `AnimatedSprite3D` used as the frame source). Their shader writes a screen-aligned quad directly in clip space, from a pure `SpriteProjection` function. Its depth is that of an upright card at the foot anchor.
- **Every 3D mode scene** contains exactly one `DioramaStage`, which owns the camera, the environment, the light rig and the sky card.
- **A `PresentationDirector` service** applies data-driven `LightingProfile`s on `mode_entered`, and writes the global uniforms through a sink.
- **The battle camera** is level and uses `PROJECTION_FRUSTUM`. Its `frustum_offset` carries both the stage's lens shift and the hit-punch.
- **Boot warms every pipeline** play will use, and the pipeline-compilation counters prove that nothing compiles afterwards.
- **A `FlashGate` service** books every large-area luminance transition at its landing time.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (Forward+). **Backend pinned to Vulkan** (`rendering/rendering_device/driver.windows = "vulkan"`, §10). On the development PC, 4.7.2 resolves to Vulkan (observed in the spike and by the fifth review's godot-specialist), which contradicts the engine reference's "D3D12 default on Windows since 4.6" (`modules/rendering.md`). The pin makes the signed-off look the shipped look |
| **Domain** | Rendering |
| **Layer** | Core |
| **Knowledge Risk** | HIGH. Rendering changed in 4.5 (Shader Baker, SMAA, stencil), 4.6 (glow before tonemapping, D3D12 default, AgX controls, SSR rework) and 4.7 (`AreaLight3D`, HDR output, thinner `CanvasItem` lines, `LinearToSRGB` unclamped) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/rendering.md`; a `ClassDB` probe of the installed 4.7.2 binary (2026-10-22) |
| **Post-Cutoff APIs Used** | None required. Shader Baker (4.5) is used at export. The 4.6 glow order and AgX controls affect how profiles are *tuned*, not which API is used. `AreaLight3D` and HDR output (4.7) are **deliberately not used**. **Probed on 4.7.2 (exists; behaviour still to verify):** `Camera3D.PROJECTION_FRUSTUM` (= 2) and `frustum_offset`; `RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_{CANVAS, MESH, SURFACE, DRAW, SPECIALIZATION}` and the matching `Performance.PIPELINE_COMPILATIONS_*` monitors. **NOT SOURCEABLE** (pre-cutoff by training, absent from the reference): `AnimatedSprite3D`/`SpriteBase3D` properties; `material_override` with a `ShaderMaterial` on a sprite; writing `POSITION` in a spatial `vertex()`; `render_mode ambient_light_disabled`; global shader uniforms; `CameraAttributesPractical` DOF; `light_cull_mask` / `layers`; `Camera3D.keep_aspect` |
| **Verification Required** | **Windowed spike on 4.7.2, 2026-10-21** (RTX 4080 SUPER, Vulkan), results:<br>(1) **PASS:** nearest-filtered, alpha-cut sprite pixels render crisp, lit by the key light.<br>(2) **The override receives nothing from the sprite** (no texture, cut-out, filter or billboard), so the shader owns all of it (§2).<br>(3) **PASS:** a `mode_time` global uniform set at runtime changes shader output.<br>(4) **PASS:** camera re-entry restores the view.<br>(5) **PASS:** `light_cull_mask` isolates the key light to actors and the set light to the set.<br>**Observed by the fifth review's godot-specialist:**<br>(6) the `Environment` sky does **not** shift with `frustum_offset`, hence the sky card (§3);<br>(7) `RenderingServer.global_shader_parameter_get()` returns null at runtime, hence the sink (§4);<br>(8) a `SubViewport` does not inherit the project's MSAA, screen-space AA or positional shadow atlas size (2048 vs 4096 observed), hence the capture tool sets them explicitly (§13);<br>(9) the backend resolves to Vulkan.<br>**Still to verify in Step 1:**<br>(10) the clip-space quad of §2: pixel-exact placement with `frustum_offset` non-zero, and upright-card depth against set geometry under the pitched Overworld camera;<br>(11) the `frustum_offset` sign and units, under `KEEP_HEIGHT` and `KEEP_WIDTH`;<br>(12) `ambient_light_disabled` plus key-only lighting on actors;<br>(13) manual frame stepping of `AnimatedSprite3D` with its own playback stopped;<br>(14) flip-based mirroring done in the shader;<br>(15) reading the glow input before tonemapping (compositor hook) for the capture tool;<br>(16) which lighting parameters change a pipeline, measured with the counters (§11) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data storage), **Accepted**: `sprite_set_id` on Character/Enemy records.<br>**ADR-0002** (Game State & Scene Flow), **Proposed**: `ModeHost`, `mode_entered`, transition and overlay announcements, `GameStateMachine.mode_time`, the detach freeze.<br>**ADR-0004** (Content Boot Ordering), **Proposed**: `register_record_validator`.<br>**ADR-0006** (Battle Replay Ownership), **Proposed**: the beat clocks that drive beat-driven sprite frames, the punch and the takeover blend.<br>ADR-0005 cannot be Accepted before ADR-0002, ADR-0004 and ADR-0006 |
| **Enables** | Overworld Exploration & Encounters ADR (the overworld diorama, its follow camera and occupation-gradient profiles); the Turn Battle presentation story; UI Framework ADR (the Menu's blurred backdrop, and the flash gate for UI transitions) |
| **Blocks** | Sprite & Camera Presentation epic; Overworld Exploration & Encounters epic (one of its 3 prerequisite ADRs) |
| **Ordering Note** | The GDD exists (revision 6). This ADR is not Accepted (at `workflow: full`) until `/architecture-review` assigns the GDD's TR IDs and they are back-filled into GDD Requirements Addressed, and until the user ratifies the D1–D4 art-direction rulings (GDD Open Question 18). Exact `battle_fov`, stage camera values and sprite height wait for Migration Step 1 |

## Context

### Problem Statement
The art bible fixes the look in its Visual Rule ("paint the rules in light and color; tell the jokes in pixels"), its Principle 2 ("the diorama is the stage; the sprites are the actors"), and its Production Notes (one pixel scale, nearest filtering, no sub-pixel rotation or scaling; 3D sets and pixel-art actors; a fixed battle camera with about 2 facings). §2 gives every state its own lighting signature. The GDD (revision 6) turns these into requirements this ADR must build:
- each sprite texel is exactly `T × T` screen pixels (`T = max(1, floor(H/360))`) at every depth, so distance never changes a sprite's size (GDD rule 2, ruling D3);
- a level battle camera framing the ground by lens shift, with the hit-punch as a whole-pixel shift of every depth (rules 4 and 8, ruling D4);
- upright-card occlusion under the pitched Overworld and Camp cameras (rule 2);
- a dusk boss flood on a sky that is always in frame (rule 6, rulings D1 and D2);
- actors lit only by their key, rim and tagged practicals, never tinted by the flood (rules 1 and 11);
- no pipeline compile in play (Formulas, `lighting_blend`, ruling 5);
- every large-area luminance source gated at the transitions' landing times (rule 13).

The systems index lists the top technical risk: "mixed pixel scales and `Sprite3D` filtering/scaling in Godot 4.7 could make the HD-2D look cheap".

### Constraints
- **ADR-0002 (Proposed):** modes are scenes under `ModeHost`; the Overworld is *detached* during battles; the Menu disables `ModeHost` processing; presentation reacts to announcements and never polls; no mutable autoloads; services under `GameRoot/Services` get the machine via `setup()`.
- **ADR-0001:** records reference art by **asset ID**; presentation maps IDs to files.
- **ADR-0006:** beat-driven frames, the punch's `t` and the takeover blend come only from the controller's clocks; presentation runs no tween, timer or sprite playback for them.
- **Coding standard:** values that look or feel like tuning are data.
- **Performance:** 60 fps, 16.6 ms, at most 2000 draw calls (`project.yaml`). The battle sub-budget is the GDD's `battle_draw_call_budget` (Pending, its Open Question 13).
- **Solo developer:** the animation workload is the cost driver, which is why the camera is fixed and characters have 2 facings.

## Decision

**1. Sprites: `CharacterSprite`, constant on-screen scale.** Every character, enemy and comedy-VFX sprite is a `CharacterSprite` scene (`src/presentation/character_sprite.tscn`). Its root is an `AnimatedSprite3D`, used as the node, the frame source and the culling bounds.
- **Scale and layers.** The node's `scale` stays `(1, 1, 1)`, and it is never rotated. It sits on visual layer 2 (`ACTORS`); the diorama is on layer 1 (`SET`).
- **Size comes from `T`, not the world.** On-screen size comes only from `T` (§2). There is no `pixels_per_unit` render parameter. `pixel_size` is set once, from `PresentationConfig`, only so the node's culling bounds cover the quad.
- **Facings.** Facings are `front` and `back`, and `SpriteFrames` animations are named `<animation_id>_<facing>`. Mirroring is a shader flip uniform, never `flip_h`, which the override ignores. A `no_mirror` animation instead has an authored `<animation_id>_<facing>_mirrored` animation, used in place of the flip.
- **Frames.**
  - **Beat-driven frames** (wind-up, follow-through, reactions, the boss `intro`) are set by `CharacterSprite` from ADR-0006's clocks every frame. The node's own playback is stopped (`stop()`).
  - **Ambient frames** (idle, walk) are stepped by `CharacterSprite` on mode time in its own `_process`, which freezes under the Menu with `ModeHost`.
  - **The frame texture.** Whenever `CharacterSprite` changes `animation` or `frame`, it sets the frame texture uniform in the same call, without relying on `frame_changed`.

**2. The sprite shader owns projection, depth and lighting.** `CharacterSprite` uses its own `material_override` `ShaderMaterial` instance (`sprite_actor.gdshader`). One instance per sprite is required, because a sampler can't be an `instance uniform`. On 4.7.2 the override receives nothing from the sprite (verified), so it re-establishes everything.
- **Projection, from a pure function.** `SpriteProjection` (`src/presentation/sprite_projection.gd`, static and headless-testable) computes, per sprite per frame:
  - `T = max(1, floor(viewport_height / texel_base_lines))`;
  - the quad rectangle in whole screen pixels: `frame_w·T × frame_h·T`, bottom-centre at the foot anchor's projection, rounded half away from zero;
  - the **upright card**: the vertical plane through the foot anchor whose normal is the camera's forward direction projected onto the ground.

  `CharacterSprite` passes the rectangle, the viewport size, the anchor and the card normal as uniforms. AC-2 compares those uniforms with the function's output.
- **Clip-space quad.** `vertex()` writes `POSITION` directly. For each corner, it takes the rectangle corner's NDC point, casts the view ray through it (`INV_PROJECTION_MATRIX`), intersects the ray with the upright card, and outputs `PROJECTION_MATRIX × (that view-space point)`.
  - **The screen footprint is exactly the pixel rectangle.** The corner points project onto the rectangle's corners.
  - **Depth is exact per pixel, with no `DEPTH` write**, because the card is planar and the rasterizer interpolates clip space perspective-correctly. Early-z stays on.
  - **Under the level battle camera**, the card is parallel to the image plane, so its depth is the anchor's constant view depth.
- **Frame texture.** `uniform sampler2D frame_tex : source_color, filter_nearest;`, with the flip applied to `UV` in the shader.
- **Hard pixel edges.** `ALPHA_SCISSOR_THRESHOLD` is set in `fragment()`. Actors never use alpha-to-coverage or alpha antialiasing.
- **Lighting.** The shader is shaded, with `render_mode ambient_light_disabled`, so environment ambient never reaches an actor. Only lights whose cull mask includes `ACTORS` light it: the `KeyLight`, and practicals the stage tags as actor-lighting (the campfire).
- **Rim.** The rim is added in `fragment()` on the **rim texel ring**: opaque texels that are not Outline Ink (`#1A1418`, matched within a small tolerance) and are 4-adjacent to an Outline Ink texel that borders transparency. The rim never lands on the outline (GDD rule 1). Its color and strength come from the global uniforms. Step 1 may replace the in-shader test with a mask baked at import.
- **No shadows.** Actors have `cast_shadow = OFF`. They get a blob shadow instead (§3).
- **Fallback, if item (10) fails.** The clip-space quad is replaced by a screen-aligned billboard whose `pixel_size` uniform is set per frame to `T · z / f_px`, using the same projection function. AC-2's node-scale clause still holds, and only the occlusion guarantee under pitched cameras is lost. A failure is recorded in this ADR before any story builds on the fallback.

**3. One `DioramaStage` per 3D mode scene.** Every mode scene that renders 3D (Overworld, Battle, Camp; Title may) contains exactly one `DioramaStage` (`src/presentation/diorama_stage.gd`). It owns:
- **The camera:** that mode's `Camera3D` (§6).
- **The environment:** one `WorldEnvironment` whose `Environment` and `CameraAttributesPractical` are local to the scene. The background is a plain color, which the sky card always covers (AC-35 checks for the clear class). Ambient light energy is 0: the set's fill comes from `FillLight`, and actors take no ambient anyway.
- **The light rig:**
  - `KeyLight`: a `DirectionalLight3D`, culled to `ACTORS`, with no shadows;
  - `SetLight`: a `DirectionalLight3D`, culled to `SET`, the **only** shadow caster in the scene;
  - `FillLight`: a `DirectionalLight3D`, culled to `SET`, with no shadows. The set's key:fill ratio is `SetLight` energy over `FillLight` energy;
  - optional authored practicals (`OmniLight3D`/`SpotLight3D`) on `SET`. A practical that also lights actors (the campfire) adds `ACTORS` to its cull mask and is tagged `actor_lighting`.
- **The sky card:** a `SkyCard` (`MeshInstance3D`) on `SET`, tagged `sky` for the capture tool's ID pass. It is an unlit quad far behind the set, sized to cover the frustum at every supported aspect (4:3 to 21:9), with `sky_card.gdshader`. Its uniforms are a vertical gradient, a horizon band (color, width, intensity: the neon horizon), a cloud layer scrolled by `mode_time`, and an energy that `k_state` scales. The `Environment` sky is not used, because it does not follow `frustum_offset` (observed), and a lens-shifted camera would show its horizon in the wrong place.
- **Blob shadows:** one per actor. A small unlit decal or mesh on `SET` under the foot anchor, offset along `SetLight`'s ground-projected direction by `shadow_offset`, colored with the profile's `shadow_color`.

The stage joins the group `&"active_diorama_stage"` on `_enter_tree()`, leaves it on `_exit_tree()`, and sets `camera.current = true` on `_enter_tree()` (Step 1 verifies that this re-applies when the Overworld is re-attached). ADR-0002 keeps exactly one mode in the tree, so the group has at most one member. Only `PresentationDirector` reads it, and only on `mode_entered`: with 0 members (a 2D mode) it does nothing, and with more than 1 it logs an error and applies none. It is registered (`presentation_stage_lookup`) so the pattern isn't copied elsewhere.

**Profile requests.** The stage exposes `profile_id: StringName` and `request_profile(id, blend_time, clock := Callable())`:
- The owning mode sets `profile_id` before the stage enters the tree. A Battle mode picks `battle` or `boss_<faction>` from its encounter descriptor.
- **With a `clock`**, the stage evaluates the GDD's `lighting_blend` from `clock.call()` every frame and runs **no tween of its own**. The Battle mode passes a clock that returns `controller.get_hold_time()` for the boss takeover (ADR-0006).
- **Without one**, it blends with a tween on itself, which freezes under the Menu with everything else in the mode. Victory and Defeat use this path, at 1×.

**4. `PresentationDirector` (a service under `GameRoot/Services`) applies profiles.** It is created by `GameRoot` and given the `GameStateMachine`, the `PresentationConfig` and a `GlobalUniformSink` via `setup()`.
- **On `mode_entered(to)`**, which fires at the end of SWAP, before the reveal, it takes the group's single stage, if any, and applies `profiles[stage.profile_id]` with `blend_time = 0`, hidden behind the wipe.
- **On `overlay_opened(MENU)` / `overlay_closed(MENU)`**, it calls `stage.set_ambient_paused(true/false)`. Dialogue and the Defeat Prompt don't pause ambience.
- **Every frame** (`PROCESS_MODE_ALWAYS`), it writes the global uniforms through the sink: `mode_time` from `machine.mode_time` (which stops under the Menu), and `actor_rim_color`/`actor_rim_strength` from the stage's current blended values.
- **The sink.** `GlobalUniformSink` is an interface. The production sink calls `RenderingServer.global_shader_parameter_set()`, and the test sink records values. `global_shader_parameter_get()` returns null at runtime on 4.7.2 (observed), so nothing, tests included, may read the globals back from the engine.
- **One door:** the Director calls only `stage.apply_profile()` and `stage.set_ambient_paused()`, and reads `profile_id` and the current rim values. The stage writes its own children.

**5. `LightingProfile` and `PresentationConfig` are data.**

`LightingProfile` is a `Resource` (`src/presentation/lighting_profile.gd`), with `.tres` files under `data/presentation/profiles/`. It holds:
- **Lights:** the actor key's color, energy and angle (it casts no shadow, so a profile may aim it); the set light's color and energy, never its angle (the diorama's sun direction is authored per stage); the fill's color and energy; the rim's color and strength.
- **Sky card:** its gradient, horizon band, cloud tint and energy. A `boss_<faction>` profile carries the faction's dusk flood swatch here.
- **Tone and glow:** tonemapper and exposure, AgX white and contrast; glow intensity, `glow_threshold` (required) and glow bloom, which must be 0 (validated).
- **Depth of field:** far enabled, far distance and amount; near enabled, which is false in every battle-family profile (GDD rule 2).
- **Shadow:** `shadow_color`, for the blob shadows.
- **Blend:** `blend_time`.

MVP profiles: `title`, `overworld`, `battle`, `boss_bureaucratia`, `boss_megacorp`, `camp`, `victory`, `defeat`. `occupied_*` and `dungeon` come with the Overworld ADR's regions. Profiles are presentation config, not Content Data records.

`PresentationConfig` (`data/config/presentation_config.tres`) holds:
- `texel_base_lines` (360) and `humanoid_height_px`;
- `battle_fov`, and the follow camera's values;
- the profile table and the sprite-set table, as untyped `Dictionary`s from an ID to a `res://` path `String`. A loader check rejects non-`String` keys or values;
- **every GDD knob** from Tuning Knobs: the replay knobs (ADR-0006 §9), the lighting levels and blend times, the read-order and flood thresholds, the punch, the follow camera and the input guard.

Its **load validation** is the GDD's list (Formulas, `replay_time`, "Load-time validation"). Each rule is a boot content error naming the rule.

**6. Cameras.**
- **Battle: level, shift-lens, `PROJECTION_FRUSTUM`.** Each battle stage authors one fixed `Camera3D` with `projection = PROJECTION_FRUSTUM`, pitch 0 and a yaw for the arc.
  - **Size and aspect.** `size = 2 · near · tan(battle_fov / 2)`, with `keep_aspect = KEEP_HEIGHT` at 16:9 and wider, and `KEEP_WIDTH` below 16:9 (switched on the viewport's `size_changed`), so narrower windows keep the 16:9 horizontal view.
  - **Lens shift.** `h_near` is the frame height at the near plane: `size` under `KEEP_HEIGHT`, `size / aspect` under `KEEP_WIDTH`. The lens shift places the horizon at the stage's `horizon_frac`: `frustum_offset.y = −(0.5 − horizon_frac) · h_near`. The sign is Step 1 item (11).
  - **Hit-punch.** The punch adds `(px_x · h_near / H, −px_y · h_near / H)` to `frustum_offset`, where `(px_x, px_y)` is the GDD's `hit_punch` offset in screen pixels with y down.
  - **Never moves.** The camera's position, rotation, `size` and `near` never change in a fight. `h_offset`/`v_offset` stay 0, and a translation shake is forbidden: it moves near and far depths by different amounts.
- **Overworld:** a perspective follow camera (`FollowCamera`) at a fixed yaw and pitch, moving position only, with `keep_aspect` switched as above. The GDD's `follow_camera` formula, including `F_v_eff`, is implemented exactly. The Overworld ADR decides what it follows.
- **Camp and Title:** a fixed `Camera3D`. Camp may be pitched.

The 3D viewport renders at the native window size (render scale 1.0, no 3D scaling or upscaler). The UI Framework ADR pins the window stretch mode for the UI.

**7. Ambient motion uses `mode_time`, never `TIME`.** The global shader uniform `mode_time: float`, declared in `project.godot`'s shader globals, is the only clock for world shaders, the sky card's clouds included. A world shader in a mode scene must never read `TIME`. That covers shader files, shader code embedded in scenes and resources, and visual shaders' Time nodes. Node-driven ambient motion already freezes, because ADR-0002 disables `ModeHost`, and particles are paused by the stage on `overlay_opened(MENU)`. This closes ADR-0002's shader-`TIME` risk.

**8. The Menu backdrop blur belongs to the UI, over a frozen frame.** The Menu overlay's full-screen `MOUSE_FILTER_STOP` backdrop (ADR-0003) blurs the screen texture with a canvas shader. The world is frozen (ADR-0002) and keeps rendering the same frame. This ADR changes no lighting for the Menu. The backdrop's opening and closing are flash-gated sources (§12).

**9. Boot validation.** `ContentBootstrap.run()` (ADR-0004) loads `PresentationConfig` with `ResourceLoader.load()`, builds `PresentationValidators` from it, registers them, and returns the config for `PresentationDirector.setup()`. The validators:
- **Records:**
  - `sprite_set_exists`, for `character` and `enemy` records. `sprite_placeholder` maps to a checkerboard. The enemy validator takes effect after ADR-0001's enemy migration;
  - `boss_profile_exists`, for alien `faction` records.
- **Sprite sets:**
  - `required_animations`: rule 10's table, `victory` for squad sets and `intro` for boss sets included;
  - `impact_frame` on every action animation, and `land_frame` on every `knockout`;
  - `intro` no longer than `boss_hold` at 1×;
  - no duplicate move-specific animation names within a set.
- **Configuration:**
  - `PresentationConfig`'s load rules (§5);
  - every `LightingProfile`: glow bloom 0, a `glow_threshold` present, near DOF off in battle-family profiles, and `set_key_fill_ratio_boss` above every non-boss profile's `SetLight`/`FillLight` energy ratio;
  - every flash source declaration (§12).

**10. Anti-aliasing, output and backend.**
- **Anti-aliasing:** screen-space AA (FXAA, SMAA) and TAA are **off**. MSAA 3D at 2× smooths the low-poly diorama silhouettes without touching texture interiors or alpha-cut edges (verified).
- **Output:** HDR output (4.7) is off, and the 3D render scale is 1.0 with no upscaler.
- **Backend:** `rendering/rendering_device/driver.windows = "vulkan"` is pinned.

All are set in `project.godot`, and AC-47 checks them.

**11. Nothing compiles in play: the measured contract and Boot warm-up.**
- **The contract.** After Boot, no preset switch, blend, discrete parameter change, or cycle through a mode's states compiles a rendering pipeline (GDD `lighting_blend`, ruling 5). It is **measured**, not assumed. AC-64 records every `Performance.PIPELINE_COMPILATIONS_*` monitor (canvas, mesh, surface, draw, specialization; probed on 4.7.2) before and after a scripted state cycle, from an empty shader cache.
- **Parameters believed to change a pipeline**, to be confirmed with the counters in Step 1 (item 16):
  - `Environment` glow, fog, volumetric fog, SSAO, SSIL and SSR enabled;
  - DOF near/far enabled on `CameraAttributes`;
  - the tonemapper mode;
  - a light's `shadow_enabled` and the light's type;
  - material features (transparency mode, cull mode, any `render_mode` change);
  - the MSAA level;
  - the positional shadow atlas size.
- **Parameters believed not to:** energies, colors, glow intensity and threshold, DOF distances and amount, exposure, AgX white and contrast, and every shader uniform.
- **The rule.** In play, a profile may change only non-compiling parameters, or switch compiling ones among combinations warmed at Boot. Step 1 publishes the confirmed list here.
- **Boot warm-up.** Behind the Boot screen, in the **main viewport** (pipelines are keyed by framebuffer format and MSAA, so warming in a differently configured `SubViewport` warms the wrong pipelines), Boot renders a warm-up stage. That stage draws every shipped sprite, set, sky-card and VFX material under every (mode, profile) combination's compiling parameters, for at least 2 frames each. Shader Baker (4.5) runs at export as well. The export option isn't sourceable here; it is verified at the first export.

**12. `FlashGate` (a service under `GameRoot/Services`).** It implements the GDD's `flash_gate`:
- **Clock.** A real-time clock is injected (integer microseconds in tests), so the Menu never resets it.
- **Declarations.** Each source has a `FlashSourceDecl` resource holding:
  - its class (gated, reserved, area-exempt or swing-exempt);
  - its transitions: offset, direction, general or red, and area as a share of a 10° window;
  - its capped variant's declared peak swing;
  - for area-exempt sources, its largest area.

  They are validated at boot (§9).
- **Requests.**
  - `request(source_id, t_offset_base := 0.0) -> bool` books a gated source's transitions at `now + offset` iff no closed one-second window would then hold more than `flash_rate_max` flashes, counted as transitions that oppose their predecessor. With Reduce Flashing On it always returns false.
  - `book_reserved(source_id)` books unconditionally.
  - `begin_exempt(source_id) -> int` and `end_exempt(handle)` track `A_exempt`. When the sum would reach `flash_area_min`, `begin_exempt` returns `-1`, and the caller requests the gate instead.
- **Consumers.** Game State (the retry flash, wipes and fades) and the UI Framework (the Menu backdrop, the Defeat card stamp, the results screen) receive the gate through `setup()`, like every service. The gate never delays a source.

**13. The capture tool is built, not assumed.** Migration Step 1c builds `tools/capture/presentation_capture.gd` as its own story, from the test plan's P-09 specification:
- **Viewport.** An offscreen `SubViewport` that sets MSAA, screen-space AA and the positional shadow atlas size **explicitly** from the project settings (item 8), and records them.
- **Passes:**
  - the ID pass, through per-class override materials on the same frame;
  - the set-light shadow mask;
  - the unlit-albedo mode;
  - the UI layer alone;
  - the glow-input hook (item 15).
- **Output:** the measurements file.

It is a Visual/Feel tool, so it runs windowed on the development PC. Every [C] clause in the GDD names this tool and gates the story that ships the measured feature.

### Architecture Diagram

```
 GameRoot
 ├── ModeHost
 │   └── <mode scene>  (only one in tree; Overworld detached during Battle — ADR-0002)
 │       └── DioramaStage  ── group "active_diorama_stage", camera.current on _enter_tree
 │           ├── Camera3D  Battle: PROJECTION_FRUSTUM, pitch 0, frustum_offset = lens shift + punch
 │           │             Overworld/Camp: perspective, fixed pitch (FollowCamera in Overworld)
 │           ├── WorldEnvironment (local Environment, ambient 0; local CameraAttributesPractical DOF)
 │           ├── KeyLight (ACTORS, no shadows)  SetLight (SET, the only shadow caster)  FillLight (SET)
 │           ├── practicals (SET; + ACTORS if tagged actor_lighting)   set geometry (SET)
 │           ├── SkyCard (SET, unlit, tagged sky; gradient · neon horizon band · clouds on mode_time)
 │           ├── blob shadows (SET, one per actor)
 │           └── actors: CharacterSprite (ACTORS, cast_shadow OFF, sprite_actor.gdshader)
 │                 uniforms from SpriteProjection: pixel rect (T = floor(H/360)), anchor, card normal
 │                 vertex(): clip-space POSITION on the upright card  ·  no ambient  ·  rim inside outline
 ├── OverlayHost ── Menu backdrop: MOUSE_FILTER_STOP + screen-blur canvas shader (UI, §8)
 └── Services
     ├── PresentationDirector (ALWAYS) ── mode_entered → apply profile (blend 0)
     │       every frame → GlobalUniformSink: mode_time, actor rim
     └── FlashGate (real-time clock) ◄── Game State (retry flash, wipes) · UI (Menu, Defeat card, results)

 Boot: ContentBootstrap → PresentationValidators · warm-up stage in the main viewport (every material ×
       every compiling-parameter combination) · Shader Baker at export
```

### Key Interfaces

```gdscript
## src/presentation/sprite_projection.gd — pure, static, headless-testable
class_name SpriteProjection extends RefCounted
static func texel_scale(viewport_height: int, base_lines: int) -> int
static func screen_rect(anchor_world: Vector3, cam: CameraState, frame_size: Vector2i,
		viewport_size: Vector2i, base_lines: int) -> Rect2i          # bottom-centre = rounded projection
static func card_normal(cam: CameraState) -> Vector3                  # camera forward, projected to ground
static func card_depth(ndc: Vector2, anchor_world: Vector3, cam: CameraState) -> float   # for tests (AC-68)
# CameraState: a value copy of the camera's transform, projection, size, near, keep_aspect, frustum_offset

## src/presentation/character_sprite.gd
class_name CharacterSprite extends AnimatedSprite3D
func setup(sprite_frames: SpriteFrames, config: PresentationConfig) -> void   # own ShaderMaterial; stop()
func show_frame(animation_id: StringName, facing: StringName, mirrored: bool, frame: int) -> void
#   sets animation/frame AND frame_tex in one call; picks <id>_<facing>_mirrored for no_mirror animations
func step_ambient(mode_dt: float) -> void          # idle/walk only; beat-driven frames come from ADR-0006 clocks
func reset_to_idle() -> void                        # on BattleReplayController.display_resynced

## src/presentation/diorama_stage.gd
class_name DioramaStage extends Node3D
const GROUP := &"active_diorama_stage"
const LAYER_SET := 1
const LAYER_ACTORS := 2
@export var profile_id: StringName
@export var camera: Camera3D
@export var world_environment: WorldEnvironment
@export var key_light: DirectionalLight3D
@export var set_light: DirectionalLight3D
@export var fill_light: DirectionalLight3D
@export var sky_card: MeshInstance3D
@export var horizon_frac: float                     # battle stages
func request_profile(id: StringName, blend_time: float, clock: Callable = Callable()) -> void
func apply_profile(profile: LightingProfile, blend_time: float) -> void   # Director only
func set_ambient_paused(paused: bool) -> void
func set_punch_offset_px(offset: Vector2i) -> void  # battle: adds to frustum_offset (§6)
var current_rim_color: Color
var current_rim_strength: float

## src/presentation/presentation_director.gd  (GameRoot/Services)
class_name PresentationDirector extends Node
func setup(machine: GameStateMachine, config: PresentationConfig, sink: GlobalUniformSink) -> void

## src/presentation/global_uniform_sink.gd
class_name GlobalUniformSink extends RefCounted
func set_global(name: StringName, value: Variant) -> void    # prod: RenderingServer.global_shader_parameter_set

## src/presentation/flash_gate.gd  (GameRoot/Services)
class_name FlashGate extends Node
func setup(clock: Callable, config: PresentationConfig, decls: Dictionary, settings: Object) -> void
func request(source_id: StringName) -> bool          # gated: books at now + each offset, or false (play capped)
func book_reserved(source_id: StringName) -> void
func begin_exempt(source_id: StringName) -> int       # -1 = treat as gated
func end_exempt(handle: int) -> void

## src/presentation/lighting_profile.gd — data only (abridged)
class_name LightingProfile extends Resource
@export var key_color: Color
@export var key_energy: float
@export var key_rotation_deg: Vector3
@export var set_color: Color
@export var set_energy: float
@export var fill_color: Color
@export var fill_energy: float
@export var rim_color: Color
@export var rim_strength: float
@export var sky_top: Color
@export var sky_bottom: Color
@export var sky_horizon: Color
@export var sky_horizon_width: float
@export var sky_horizon_intensity: float
@export var sky_energy: float
@export var exposure: float
@export var agx_white: float
@export var agx_contrast: float
@export var glow_intensity: float
@export var glow_threshold: float
@export var glow_bloom: float              # must be 0 (validated)
@export var dof_far_enabled: bool
@export var dof_far_distance: float
@export var dof_amount: float
@export var dof_near_enabled: bool          # false in every battle-family profile (validated)
@export var shadow_color: Color
@export var blend_time: float

## Global shader uniforms (project.godot shader_globals)
#   mode_time: float      — the ONLY clock world shaders may read
#   actor_rim_color: color, actor_rim_strength: float
```

### Implementation Guidelines
- **Sprites:**
  - Every character, enemy and comedy-VFX sprite **must** be a `CharacterSprite`, with scale `(1, 1, 1)` and no rotation.
  - Its on-screen rectangle **must** come only from `SpriteProjection.screen_rect()`, through the shader's clip-space quad.
  - Each `CharacterSprite` **must** own its own `ShaderMaterial`, and **must** set `frame_tex` in the same call that changes `animation` or `frame`.
  - Beat-driven frames **must** come from ADR-0006's clocks. The node's own playback **must** stay stopped.
  - The actor shader **must** keep `ambient_light_disabled`, `filter_nearest` and `ALPHA_SCISSOR_THRESHOLD`, and **must never** put the rim on Outline Ink texels.
- **Lights, shadows and layers:**
  - `cast_shadow` **must** be OFF on every actor.
  - Only `SetLight` may cast shadows. `KeyLight` **must** cull to `ACTORS` only, and `SetLight` and `FillLight` to `SET` only.
  - The `Environment`'s ambient energy **must** be 0, and its sky **must not** be used. The `SkyCard` is the only sky.
- **Battle camera:**
  - It **must** be `PROJECTION_FRUSTUM` with pitch 0, and its only per-frame change is `frustum_offset` (lens shift + punch).
  - `h_offset`, `v_offset`, a translation shake and a rotation shake are forbidden.
- **Stages:** every 3D mode scene **must** contain exactly one `DioramaStage`, and no second `Camera3D` or `WorldEnvironment`.
- **Clocks:**
  - World shaders **must never** read `TIME`; they read `mode_time`. UI shaders outside `ModeHost` may.
  - The takeover blend **must** run from the clock passed to `request_profile()`, never a tween.
- **One door:**
  - Only `PresentationDirector` may call `apply_profile()` or `set_ambient_paused()`, read the stage group, or write the global uniforms, and it writes only through `GlobalUniformSink`.
  - Nothing may read a global uniform back from `RenderingServer`.
- **Data:**
  - Lighting, FOV, camera, texel and timing values **must** come from `PresentationConfig` and `LightingProfile` `.tres` files, never literals.
  - Each stage's `Environment` and `CameraAttributes` **must** be local to the scene.
- **Compile contract:**
  - A profile **must not** switch a compiling parameter (§11) to a combination Boot didn't warm.
  - Boot's warm-up **must** run in the main viewport.
- **Flash gate:** every large-area luminance source **must** have a `FlashSourceDecl` and go through `FlashGate`.
- **Forbidden without an amendment to this ADR:** `AreaLight3D`, HDR output, FXAA, SMAA, TAA, an upscaler and a render scale below 1.0.

## Alternatives Considered

### Alternative 1: 2D sprites on a `CanvasLayer` over a 3D world
- **Description**: Render the diorama in 3D, then draw sprites as 2D nodes at unprojected positions.
- **Pros**: Pixel-perfect screen-space scale, simple 2D tooling.
- **Cons**: Sprites aren't lit by the scene (no campfire flicker on them, no shared light) and can't be occluded by set geometry; depth sorting with props becomes manual.
- **Rejection Reason**: Breaks "lit inside the diorama" and the occlusion guarantee. §2 gets 2D's constant scale while keeping 3D lighting and depth.

### Alternative 2: Separate `SubViewport`s for set and actors, composited
- **Description**: Render actors into a low-res pixel layer and composite.
- **Pros**: True pixel-grid snapping.
- **Cons**: Lighting and depth don't cross viewports; doubles passes; the same pipeline risk ADR-0002 rejected.
- **Rejection Reason**: Too much pipeline risk.

### Alternative 3: Orthographic camera
- **Description**: An orthographic `Camera3D`.
- **Pros**: Constant pixel size everywhere.
- **Cons**: Loses the tilt-shift toy-table depth and perspective staging of the set.
- **Rejection Reason**: The set needs perspective; §2 gives actors constant size without making the set orthographic.

### Alternative 4: Each mode scene lights itself, with no Director
- **Description**: Stages load and apply their own profiles.
- **Pros**: One fewer node.
- **Cons**: Stages would need the config injected, and the global uniforms still need an always-processing owner outside `ModeHost`.
- **Rejection Reason**: The Director is the single always-processing owner of global presentation state.

### Alternative 5: Revision 1's Y-locked, world-scaled billboard
- **Description**: A billboard locked to world up, sized by a world `pixel_size`, so on-screen size falls with distance.
- **Pros**: Stock-like; sprites shrink with distance like the set.
- **Cons**:
  - mixed pixel scale between rows, the art bible's #1 failure;
  - non-square texels off-centre under perspective, which needed a stretch correction;
  - sprites lean against the set under a pitched camera;
  - one constant depth clipping upper bodies into the set.
- **Rejection Reason**: The fifth review's ruling D3 (constant integer texels) and its findings.

### Alternative 6: The `Environment` sky with a pitched battle camera
- **Description**: Keep the engine sky, and pitch the battle camera down to frame the ground.
- **Pros**: No sky card; standard camera.
- **Cons**: A pitched camera leans every upright sprite back against the set's verticals. With a lens shift instead, the engine sky's horizon doesn't follow `frustum_offset` (observed). The sky could also fall out of frame entirely.
- **Rejection Reason**: Rulings D2 and D4: a level, shift-lens camera with a backdrop sky card.

## Consequences

### Positive
- **No mixed pixel scale.** It is impossible by construction at any depth and window size: one integer `T`, from one function, tested headlessly (AC-2, AC-58).
- **Exact occlusion.** Upright-card occlusion is per-pixel exact with no `DEPTH` write, so early-z stays on.
- **A level battle camera** keeps the set's verticals parallel to the sprites, and the lens shift makes the hit-punch a pure whole-pixel shift of every depth.
- **The sky is always in frame**, and fully controlled by data, which makes the dusk flood and its neon horizon simple uniforms.
- **The flood can't tint the squad**, by construction: actors take no ambient, fill or set light.
- **No compile stutter in play.** It is measured, not hoped for, with a negative control.
- **No actor shadow pass,** which removes the spike's rectangle-shadow risk and its draw calls.

### Negative
- **Distance cues.** Sprites don't shrink with distance, so depth reads only from position and occlusion (GDD Open Question 18 asks the user to ratify).
- **Size steps with the window height.** A sprite's size relative to the frame steps with `T` between window heights (GDD Open Question 19).
- **A custom vertex path** (clip-space `POSITION`) must be maintained, and depends on Step 1 item (10).
- **Every world shader author** must use `mode_time`, not `TIME`.
- **Boot does more work:** it renders a warm-up stage, which lengthens Boot.

## Risks
- **The clip-space quad misbehaves** under `frustum_offset` or in the pitched card case. *Mitigation*: Step 1 item (10), with the §2 fallback (per-frame `pixel_size`) recorded before any story builds on it.
- **The `frustum_offset` sign or units differ** from §6. *Mitigation*: Step 1 item (11), measured against `battle_framing`'s `y_h`. A fix changes one sign in `DioramaStage`.
- **A lighting parameter compiles when it was expected not to.** *Mitigation*: the counters (§11) catch it in Step 1, and the warm-up list grows.
- **The glow-input hook is unavailable.** *Mitigation*: AC-32's glow clause stays Pending, and the glow threshold is tuned by eye with a conservative margin.
- **Shader Baker's export option differs.** *Mitigation*: verified at the first export; the Boot warm-up alone already meets the contract on the development PC.
- **Thin features shimmer in the set's shadow maps.** *Mitigation*: per-stage shadow bias tuning in Step 1.

## GDD Requirements Addressed

No `TR-` IDs are registered yet for `sprite-camera-presentation.md`. `/architecture-review` assigns them, and they are back-filled here before acceptance.

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| sprite-camera-presentation.md | Rule 2: every texel is `T × T` px at every depth; screen-facing, pixel-snapped quads; upright-card occlusion | §1, §2 (`SpriteProjection`, the clip-space quad on the upright card) |
| sprite-camera-presentation.md | Rule 1: actors lit only by their key, rim and tagged practicals; a rim never on the outline; set yields | §2 (`ambient_light_disabled`, cull masks, rim texel ring), §3 light rig |
| sprite-camera-presentation.md | Rules 4 and 8: a level shift-lens battle camera; the punch as a whole-pixel shift of every depth | §6 (`PROJECTION_FRUSTUM`, `frustum_offset`) |
| sprite-camera-presentation.md | Rule 6: the dusk flood on a sky always in frame; the takeover on the replay's clock | §3 (`SkyCard`; `request_profile` with a clock), §5 (sky fields) |
| sprite-camera-presentation.md | Rule 11: the flood never tints the squad | §2, §3 (actors take no ambient, fill or set light) |
| sprite-camera-presentation.md | Rule 12: one blob shadow per actor; only the set light casts | §2 (`cast_shadow` OFF), §3 (`SetLight`, blob shadows) |
| sprite-camera-presentation.md | Rule 13: one flash gate for every large-area source, booking at landing | §12 (`FlashGate`, `FlashSourceDecl`) |
| sprite-camera-presentation.md | Formulas `lighting_blend`: nothing compiles in play | §11 (counters, warm-up in the main viewport, Shader Baker) |
| sprite-camera-presentation.md | Rendering constraints: native scale, SDR, no screen-space AA, a pinned backend, no `TIME` | §7, §10 |
| sprite-camera-presentation.md | Rule 10: required animations, `impact_frame`, `land_frame`, `intro` length | §9 |
| sprite-camera-presentation.md | Acceptance Criteria [C]: the capture tool exists | §13, Migration Step 1c |
| art-bible.md §1–§2 | One pixel scale; per-state lighting signatures; the boss flood | §1–§5 |
| game-state-scene-flow.md | Lighting on `mode_entered`; Rule 10 (Menu stops mode time) | §4, §7 |
| content-data-definitions.md | Rule 3: art by asset ID | §5 sprite-set table, §9 |
| systems-index.md | Top Presentation risk: mixed pixel scales / `Sprite3D` filtering | §2 makes mixed scale impossible; Step 1 verifies |

## Performance Implications
- **CPU:** one `SpriteProjection.screen_rect()` per sprite per frame (about 8 in a battle) and a few uniform writes. The Director writes 3 globals per frame. Negligible.
- **GPU / draw calls:** actors cast no shadows, so there is no actor shadow pass. Per battle: about 8 actor draws, 8 blob shadows, 1 sky card, the diorama (with `SetLight`'s cascades) and VFX. `FillLight` casts nothing. DOF and glow are the main GPU costs, measured in P-14. The budget is the GDD's `battle_draw_call_budget` (Pending, Open Question 13).
- **Memory:** `SpriteFrames` per character (small); the detached Overworld diorama stays resident during battles (ADR-0002).
- **Load time:** Boot's warm-up stage adds a one-off cost at boot, measured in P-15. Battle stages load inside ADR-0002's swap budget.
- **Network:** none.

## Migration Plan
No 3D presentation code exists; the battle HUD and demos are 2D `Control` scenes and are unaffected until the Turn Battle presentation story.
1. **Early technical test**, as a spike in `prototypes/sprite_camera_spike/`, not `src/`. One `CharacterSprite`-equivalent with placeholder art in a small lit diorama, a level shift-lens battle camera, a pitched overworld camera, a sky card, and the `battle`, `boss_*` and `camp` profiles. It settles Verification Required items (10)–(16), and sets `battle_fov`, `h_cam`, `horizon_frac`, slot depths and `humanoid_height_px`. Retained screenshots go in `production/qa/evidence/`, from a windowed run.
   - **1b.** Publish the confirmed compiling-parameter list in §11, and the `frustum_offset` sign in §6, in this ADR.
   - **1c. Build the capture tool** (`tools/capture/presentation_capture.gd`), **as its own story**, from the test plan's P-09: explicit `SubViewport` settings, the ID pass, the shadow mask, the unlit-albedo mode, UI-alone, and the glow-input hook, or a recorded "Pending" if item (15) fails. The flash analyser (P-13) is a separate story. Until 1c is Done, no story that ships a [C]-measured feature can close on that clause.
2. Run `/architecture-review` to assign the GDD's TR IDs, back-fill GDD Requirements Addressed, and Accept this ADR after ADR-0002, ADR-0004 and ADR-0006 are Accepted and the user ratifies D1–D4.
3. **Requires ADR-0004's implementation.** Build test-first in `src/presentation/`: `SpriteProjection`, `CharacterSprite`, `DioramaStage`, the sky card, `PresentationDirector` with `GlobalUniformSink`, `LightingProfile`, `PresentationConfig` and its validation, `FlashGate`, the validators, and the Boot warm-up.
4. With ADR-0002's Battle mode story and ADR-0006: the battle stage wraps `BattleCore` with sprites, drives frames from the controller's clocks, and keeps the existing `BattleHud` as an overlay `Control`.
5. With the Overworld ADR: the follow camera, `occupied_*`/`dungeon` profiles and region dioramas.

## Validation Criteria
- **Step 1 evidence:** screenshots (battle, one boss takeover, camp; near and far rows; a pitched overworld sprite against a wall) retained in `production/qa/evidence/` with lead sign-off.
- **`SpriteProjection` unit tests** (P-03):
  - `T` at 720, 900, 1080, 1440 and 2160;
  - the rectangle's size and rounding;
  - card-depth agreement with the analytic ray–plane intersection;
  - each run with a non-default config.
- **A `CharacterSprite` unit test:**
  - its shader uniforms equal `screen_rect()`'s output;
  - it owns a unique `ShaderMaterial`, and `frame_tex` equals the current frame's texture after every `show_frame()`;
  - `cast_shadow` is OFF;
  - layer is `ACTORS`;
  - its own playback is stopped.
- **An integration test:** Overworld → Battle → Overworld applies `overworld`, then `battle`, then `overworld` on each `mode_entered`, and the re-attached Overworld's camera is current.
- **An integration test:** with the Menu open, the sink's `mode_time` doesn't advance, and particles report paused.
- **A battle-camera test:** the camera's transform, `size` and `near` never change in a fight, and `frustum_offset` equals the lens shift plus the punch on every frame.
- **The validators:** every §9 rule fails a fixture and passes the shipped data.
- **A `FlashGate` unit test suite:** GDD AC-25.
- **The world-shader lint in CI** (GDD AC-47).
- **The compile contract:** P-15 (GDD AC-64), with its negative control.

## Related
- Depends on: `docs/architecture/adr-0001-content-data-storage-format.md` (Accepted), `adr-0002-game-state-scene-flow.md`, `adr-0004-content-boot-ordering.md` and `adr-0006-battle-replay-ownership.md` (all Proposed).
- Interacts with: `docs/architecture/adr-0003-input-system.md` (the Menu backdrop is the same `MOUSE_FILTER_STOP` control).
- Design: `design/gdd/sprite-camera-presentation.md` (revision 6); `design/art/art-bible.md` §1, §2 and §4; `design/gdd/game-state-scene-flow.md`; `design/gdd/content-data-definitions.md`; `design/gdd/systems-index.md`.
- Tests: `production/qa/test-plans/sprite-camera-presentation-test-plan.md`.
- Upcoming: Overworld Exploration ADR (follow camera, region profiles), UI Framework ADR (backdrop blur, stretch mode, UI flash sources).
- Amends `docs/architecture/architecture.md` Module Ownership (Sprite & Camera row): `mode_entered` → `PresentationDirector` → `DioramaStage.apply_profile()`; modes call `DioramaStage.request_profile()`; `FlashGate` is a new service; `AreaLight3D` is removed from the engine APIs.

## Review History
- 2026-10-21 — **godot-specialist** (engine validation): BLOCKING, then revised. On 4.7.2 a `material_override` on SpriteBase3D receives no frame texture, filter, alpha cut or billboard, so the shader owns them, with one material per sprite. The windowed spike passed global uniforms, `light_cull_mask` isolation, camera re-entry and MSAA with alpha-cut.
- 2026-10-21 — **technical-director** (TD-ADR): CONCERNS, 11 findings, all revised:
  - the one-door Director;
  - rim globals;
  - the bounded group lookup;
  - `camera.current` on enter;
  - the validator boot order;
  - `Dictionary` tables;
  - the Menu wording;
  - acceptance gated on the GDD;
  - the spike in `prototypes/`;
  - Step 3 depending on ADR-0004;
  - the set-light angle removed from profiles.
- 2026-10-22 — **Revision 2**, per the fifth `/design-review` of `sprite-camera-presentation.md` (its tracked list and rulings 4–5). Changes from revision 1:
  - **Sprites:** constant integer texels `T = H/360` from a pure `SpriteProjection`, and a clip-space quad on the upright card, replacing the Y-locked world-scaled billboard and `pixel_size` scaling. `pixels_per_unit` is retired. The rim excludes the outline. Actors take no ambient.
  - **Cameras:** a level battle camera on `PROJECTION_FRUSTUM`, with the lens shift and the punch on `frustum_offset`, replacing the translation shake.
  - **Stage:** the `SkyCard` replaces the `Environment` sky (it doesn't follow the lens shift; observed), and a `FillLight` is added.
  - **Shadows:** actor shadows off, plus blob shadows. The rectangle-shadow risk is gone, and so are the actor shadow passes.
  - **Services:** `GlobalUniformSink` (`global_shader_parameter_get()` returns null; observed), and the `FlashGate` service.
  - **Compile contract:** measured on the 4.7.2 pipeline counters (probed), with a compiling-parameter list and warm-up in the main viewport.
  - **Backend:** pinned to Vulkan (observed).
  - **Capture tool:** Step 1c, its own story, with explicit `SubViewport` settings (`SubViewport` doesn't inherit MSAA/AA or the shadow atlas; observed).
  - **Pending:** a fresh godot-specialist and TD-ADR review of this revision.
