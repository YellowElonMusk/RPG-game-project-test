# ADR-0005: Sprite & Camera Presentation — Constant-Scale Pixel Sprites in 3D Dioramas, a Level Shift-Lens Battle Camera, Data-Driven Lighting

## Status
Accepted — amended by ADR-0012 (Accepted 2026-10-23, amendment in effect, annotation only): §4's same-mode skip of the entry-profile apply covers only the same-instance `BATTLE → BATTLE` row; an in-mode fade (ADR-0002 §11) triggers no rebind and no profile apply; the Overworld resolves its lighting profile per map × faction × stage, or the liberated profile, before the stage enters the tree. **Annotation text still owed in this ADR** (TR-overworld-017): profiles keyed by faction × stage and the liberated profile, `sky_card`, interior travelling-light constraints, leader-relative tilt-shift blur bounds, and per-cue capture-ID tags (incl. `SKY`) in §13.

## Date
2026-10-21 (revision 2: 2026-10-22; revision 3: 2026-10-22)

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
| **Verification Required** | **Windowed spike on 4.7.2, 2026-10-21** (RTX 4080 SUPER, Vulkan), results:<br>(1) **PASS:** nearest-filtered, alpha-cut sprite pixels render crisp, lit by the key light.<br>(2) **The override receives nothing from the sprite** (no texture, cut-out, filter or billboard), so the shader owns all of it (§2).<br>(3) **PASS:** a `mode_time` global uniform set at runtime changes shader output.<br>(4) **PASS:** camera re-entry restores the view.<br>(5) **PASS:** `light_cull_mask` isolates the key light to actors and the set light to the set.<br>**Observed by the fifth review's godot-specialist:**<br>(6) the `Environment` sky does **not** shift with `frustum_offset`, hence the sky card (§3);<br>(7) `RenderingServer.global_shader_parameter_get()` returns null at runtime, hence the sink (§4);<br>(8) a `SubViewport` does not inherit the project's MSAA, screen-space AA or positional shadow atlas size (2048 vs 4096 observed), hence the capture tool sets them explicitly (§13);<br>(9) the backend resolves to Vulkan.<br>**Probed and VERIFIED by the review of revision 2 (godot-specialist, 4.7.2 windowed + headless, 2026-10-22):**<br>(10) the clip-space quad of §2 is pixel-exact with `frustum_offset` non-zero, with upright-card depth against set geometry under both the level battle camera and the pitched Overworld camera;<br>(11) `frustum_offset` is in near-plane units and +y moves the image down, under `KEEP_HEIGHT` (§6). `KEEP_WIDTH` is no longer used (§6 keeps `KEEP_HEIGHT` always), so its behaviour needs no further check. Residual: Step 1 re-measures the lens shift against `battle_framing`'s `y_h` at 16:9 and 16:10 (Risks);<br>**Still to verify in Step 1:**<br>(12) `ambient_light_disabled` plus key-only lighting on actors;<br>(13) manual frame stepping of `AnimatedSprite3D` with its own playback stopped. Probed 2026-10-22: `stop()` and assigning `animation` each reset `frame` to 0, so §1's call order applies; Step 1 confirms the stepped frames render in a windowed run;<br>(14) flip-based mirroring done in the shader;<br>(15) reading the glow input before tonemapping (compositor hook) for the capture tool;<br>(16) which lighting parameters change a pipeline, measured with the counters (§11) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data storage), **Accepted**: `sprite_set_id` on Character/Enemy records.<br>**ADR-0002** (Game State & Scene Flow), **Accepted** 2026-10-22: `ModeHost`, `mode_entered`, transition and overlay announcements, `GameStateMachine.mode_time`, the detach freeze.<br>**ADR-0004** (Content Boot Ordering), **Accepted** 2026-10-22: `register_record_validator`.<br>**ADR-0006** (Battle Replay Ownership), **Accepted** 2026-10-22: the beat clocks that drive beat-driven sprite frames, the punch and the takeover blend.<br>ADR-0005 cannot be Accepted before ADR-0002, ADR-0004 and ADR-0006 |
| **Enables** | Overworld Exploration & Encounters ADR (the overworld diorama, its follow camera and occupation-gradient profiles); the Turn Battle presentation story; UI Framework ADR (the Menu's blurred backdrop, and the flash gate for UI transitions) |
| **Blocks** | Sprite & Camera Presentation epic; Overworld Exploration & Encounters epic (one of its 3 prerequisite ADRs) |
| **Ordering Note** | Accepted after ADR-0002, ADR-0004, ADR-0003 and ADR-0006 (2026-10-22). Its preconditions are met: the GDD's TR IDs were assigned by `/architecture-review` on 2026-10-22 and back-filled into GDD Requirements Addressed, and the user ratified D1–D4 (GDD Open Question 18) on 2026-10-22. Exact `battle_fov`, stage camera values and sprite height wait for Migration Step 1 |

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
- **ADR-0002 (Accepted):** modes are scenes under `ModeHost`; the Overworld is *detached* during battles; the Menu disables `ModeHost` processing; presentation reacts to announcements and never polls; no mutable autoloads; services under `GameRoot/Services` get the machine via `setup()`.
- **ADR-0001:** records reference art by **asset ID**; presentation maps IDs to files.
- **ADR-0006:** beat-driven frames, the punch's `t` and the takeover blend come only from the controller's clocks; presentation runs no tween, timer or sprite playback for them.
- **Coding standard:** values that look or feel like tuning are data.
- **Performance:** 60 fps; p99 ≤ 16.6 ms and worst frame ≤ 33 ms; in a battle ≤ 300 3D + ≤ 100 canvas draw calls (`project.yaml`, user decision 2026-10-22). Targets: a GTX 1080-class desktop at 1080p and Steam Deck at 1280×800. Vulkan only.
- **Solo developer:** the animation workload is the cost driver, which is why the camera is fixed and characters have 2 facings.

## Decision

**1. Sprites: `CharacterSprite`, constant on-screen scale.** Every character, enemy and comedy-VFX sprite is a `CharacterSprite` scene (`src/presentation/character_sprite.tscn`). Its root is an `AnimatedSprite3D`, used as the node, the frame source and the culling bounds.
- **Scale and layers.** The node's `scale` stays `(1, 1, 1)`, and it is never rotated. It sits on visual layer 2 (`ACTORS`); the diorama is on layer 1 (`SET`).
- **Size comes from `T`, not the world.** On-screen size comes only from `T` (§2). There is no `pixels_per_unit` render parameter. `pixel_size` is set once, from `PresentationConfig`, only so the node's culling bounds cover the quad.
- **Facings.** Facings are `front` and `back`, and `SpriteFrames` animations are named `<animation_id>_<facing>`. Mirroring is a shader flip uniform, never `flip_h`, which the override ignores. A `no_mirror` animation instead has an authored `<animation_id>_<facing>_mirrored` animation, used in place of the flip.
- **Frames.**
  - **Beat-driven frames** (wind-up, follow-through, reactions, the boss `intro`) are set by `CharacterSprite` from ADR-0006's clocks every frame. The node's own playback is stopped.
  - **Call order (probed on 4.7.2, 2026-10-22).** `stop()` and assigning `animation` each reset `frame` to 0. So `stop()` is called **once**, in `setup()`, and never again while frames are being stepped. `show_frame()` assigns `animation` (only when it changes) **before** `frame`, or uses `set_frame_and_progress(frame, 0.0)` (probed) after the animation assignment. Assigning `frame` first, or calling `stop()` per frame, snaps every beat-driven frame to 0.
  - **Ambient frames** (idle, walk) are stepped by `CharacterSprite` on mode time in its own `_process`, which freezes under the Menu with `ModeHost`.
  - **The frame texture.** Whenever `CharacterSprite` changes `animation` or `frame`, it sets the frame texture uniform in the same call, without relying on `frame_changed`.

**2. The sprite shader owns projection, depth and lighting.** `CharacterSprite` uses its own `material_override` `ShaderMaterial` instance (`sprite_actor.gdshader`). One instance per sprite is required, because a sampler can't be an `instance uniform`. On 4.7.2 the override receives nothing from the sprite (verified), so it re-establishes everything.
- **Projection, from a pure function.** `SpriteProjection` (`src/presentation/sprite_projection.gd`, static and headless-testable) computes, per sprite per frame:
  - `T = max(1, floor(viewport_height / texel_base_lines))`, where `viewport_height` is `get_viewport().size.y` (window pixels; under ADR-0008's refit it is the full window height, and `T` is unaffected by the refit remainder while `f ≤ 6`);
  - the quad rectangle in whole screen pixels: `frame_w·T × frame_h·T`, bottom-centre at the foot anchor's projection rounded half away from zero to `(x_a, y_a)`, with `x_left = x_a − floor(frame_w·T / 2)` so an odd pixel width never starts on a half pixel (GDD `texel_scale`);
  - the **upright card**: the vertical plane through the foot anchor whose normal is the camera's forward direction projected onto the ground.

  `CharacterSprite` passes the rectangle, the viewport size, the anchor and the card normal as uniforms. AC-2 compares those uniforms with the function's output.
- **Clip-space quad.** `vertex()` writes `POSITION` directly. For each corner, it takes the rectangle corner's NDC point, casts the view ray through it (`INV_PROJECTION_MATRIX`), intersects the ray with the upright card, and outputs `PROJECTION_MATRIX × (that view-space point)`.
  - **The screen footprint is exactly the pixel rectangle.** The corner points project onto the rectangle's corners.
  - **Depth is exact per pixel, with no `DEPTH` write**, because the card is planar and the rasterizer interpolates clip space perspective-correctly. Early-z stays on.
  - **Under the level battle camera**, the card is parallel to the image plane, so its depth is the anchor's constant view depth.
  - **Shader specifics (probed on 4.7.2):**
    - the RD backends' shader-space NDC is **y-down**; the rectangle's corners are converted with that convention, or the quad comes out mirrored;
    - the corner is chosen from `VERTEX_ID` (or `sign(VERTEX.xy)` of the source quad), **never from `UV`**: a `SpriteFrames` built from an `AtlasTexture` hands the override region UVs, not 0..1;
    - `vertex()` also writes `VERTEX` (the view-space card point) and `NORMAL` (the card normal), so omni/spot practicals (the campfire) and fog see the card, not the original mesh;
    - under a **pitched** camera, `fragment()` derives the texel UV from `FRAGCOORD` and the pixel rectangle, because perspective-correct UV interpolation on a tilted card gives non-uniform texels on screen;
    - the node sets `custom_aabb` (or `extra_cull_margin`) to cover the quad, whose world size grows with depth beyond the `pixel_size` bounds.
- **Frame texture.** `uniform sampler2D frame_tex : source_color, filter_nearest;`, with the flip applied to `UV` in the shader.
- **Hard pixel edges.** `ALPHA_SCISSOR_THRESHOLD` is set in `fragment()`. Actors never use alpha-to-coverage or alpha antialiasing.
- **Lighting.** The shader is shaded, with `render_mode ambient_light_disabled`, so environment ambient never reaches an actor. Only lights whose cull mask includes `ACTORS` light it: the `KeyLight`, and practicals the stage tags as actor-lighting (the campfire).
- **Rim.** The rim is added in `fragment()` on the **rim texel ring**: opaque texels that are not Outline Ink (`#1A1418`, matched within a small tolerance) and are 4-adjacent to an Outline Ink texel that borders transparency. The rim never lands on the outline (GDD rule 1). Its color and strength come from the global uniforms. Step 1 may replace the in-shader test with a mask baked at import.
- **No shadows.** Actors have `cast_shadow = OFF`. They get a blob shadow instead (§3).
- **Fallback, kept in reserve.** Item (10) was verified on 2026-10-22; this applies only if the Step 1 stage (including the Steam Deck run) shows a regression. The clip-space quad is replaced by a screen-aligned billboard whose `pixel_size` uniform is set per frame to `T · z / f_px`, using the same projection function. AC-2's node-scale clause still holds, and only the occlusion guarantee under pitched cameras is lost. A failure is recorded in this ADR before any story builds on the fallback.

**3. One `DioramaStage` per 3D mode scene.** Every mode scene that renders 3D (Overworld, Battle, Camp; Title may) contains exactly one `DioramaStage` (`src/presentation/diorama_stage.gd`). It owns:
- **The camera:** that mode's `Camera3D` (§6).
- **The environment:** one `WorldEnvironment` whose `Environment` and `CameraAttributesPractical` are local to the scene. The background is a plain color, which the sky card always covers (AC-35 checks for the clear class). Ambient light energy is 0: the set's fill comes from `FillLight`, and actors take no ambient anyway.
- **The light rig:**
  - `KeyLight`: a `DirectionalLight3D`, culled to `ACTORS`, with no shadows;
  - `SetLight`: a `DirectionalLight3D`, culled to `SET`, the **only** shadow caster in the scene;
  - `FillLight`: a `DirectionalLight3D`, culled to `SET`, with no shadows. The set's key:fill ratio is `SetLight` energy over `FillLight` energy;
  - optional authored practicals (`OmniLight3D`/`SpotLight3D`) on `SET`. A practical that also lights actors (the campfire) adds `ACTORS` to its cull mask and is tagged `actor_lighting`.
- **The sky card:** a `SkyCard` (`MeshInstance3D`) on `SET`, tagged `sky` for the capture tool's ID pass. It is an unlit quad far behind the set, sized to cover the frustum at every supported aspect (4:3 to 21:9) at the stage's lens shift plus the largest hit-punch, with `sky_card.gdshader` (`render_mode unshaded, fog_disabled`). On a dusk flood it draws the GDD's stars: single-texel points (`T × T` px, snapped like sprites), placed above the horizon band, tagged `star` in the ID pass, twinkling on `mode_time`. Its uniforms are a vertical gradient, a horizon band (color, width, intensity: the neon horizon), a cloud layer scrolled by `mode_time`, and an energy that `k_state` scales. The `Environment` sky is not used, because it does not follow `frustum_offset` (observed), and a lens-shifted camera would show its horizon in the wrong place.
- **Blob shadows:** one per actor. A small unlit decal or mesh on `SET` under the foot anchor, offset along `SetLight`'s ground-projected direction by `shadow_offset`, colored with the profile's `shadow_color`.

The stage joins the group `&"active_diorama_stage"` on `_enter_tree()`, leaves it on `_exit_tree()`, and sets `camera.current = true` on `_enter_tree()` (Step 1 verifies that this re-applies when the Overworld is re-attached). ADR-0002 keeps exactly one mode in the tree, so the group has at most one member. Only `PresentationDirector` reads it, and only on `mode_entered`: with 0 members (a 2D mode) it does nothing, and with more than 1 it logs an error and applies none. It is registered (`presentation_stage_lookup`) so the pattern isn't copied elsewhere.

**Profile requests.** The stage exposes `profile_id: StringName` (its **entry** profile) and `request_profile(id, blend_time, clock := Callable())`:
- **Every battle stage enters on `battle`**, including a boss stage. The owning mode sets `profile_id` before the stage enters the tree; for Battle it is always `battle`. The boss light is never an entry profile, so the first-encounter takeover always has a "from" light to blend out of (GDD rule 6).
- **Lookup.** The stage holds no `PresentationConfig` and no reference to the Director. On `mode_entered`, the Director hands it a **profile resolver**: `stage.bind_profiles(resolver: Callable)`, where `resolver.call(id) -> LightingProfile` reads the config's table (null for an unknown ID, which logs an error and leaves the light unchanged). `request_profile` resolves through it.
- **Who requests the boss light.** The Battle mode, never the Director:
  - **first encounter:** on the controller's `hold_started(TAKEOVER_FULL)` it calls `stage.request_profile(&"boss_<faction>", blend_boss, clock)`, with `clock` a `Callable` returning `controller.get_hold_time()` (ADR-0006 §5 step 3);
  - **Retry:** inside the hidden SWAP (before `mode_entered`), it calls `request_profile(&"boss_<faction>", 0.0)` for an uncapped retry flash, or `request_profile(&"boss_<faction>", blend_defeat)` when the flash plays capped. That blend starts at SWAP, partway through the capped flash: a capped flash hides nothing, so Defeat → boss light is a visible blend either way, never a pop. It learns which from `GameStateMachine.is_transition_flash_capped()`, which reports the `FlashGate` result for the current transition (ADR-0002 amendment).
- **With a `clock`**, the stage evaluates the GDD's `lighting_blend` from `clock.call()` every frame and runs **no tween of its own**.
- **Without one**, it blends with a tween on itself, which freezes under the Menu with everything else in the mode. Victory, Defeat and the capped-Retry blend use this path, at 1×.
- **Core never imports Feature.** `DioramaStage` and `CharacterSprite` never reference the `BattleReplayController` type. The Battle mode connects the controller's signals to them and passes clocks as `Callable`s.

**4. `PresentationDirector` (a service under `GameRoot/Services`) applies profiles.** It is created by `GameRoot` and given the `GameStateMachine`, the `PresentationConfig` and a `GlobalUniformSink` via `setup()`.
- **On `mode_entered(to)`**, which fires at the end of SWAP, before the reveal, it takes the group's single stage, if any, calls `stage.bind_profiles(resolver)`, and applies `profiles[stage.profile_id]` with `blend_time = 0`, hidden behind the wipe.
- **Same-mode rows skip the apply.** It learns `from` and `to` from `transition_started(from, to)`. On a same-mode row (Battle → Battle for Retry, ADR-0002 §7) it rebinds but does **not** apply the entry profile, because the Battle mode has already set the Retry light during SWAP; applying `battle` at blend 0 would overwrite it.
- **On `overlay_opened(MENU)` / `overlay_closed(MENU)`**, it calls `stage.set_ambient_paused(true/false)`. Dialogue and the Defeat Prompt don't pause ambience.
- **Every frame** (`PROCESS_MODE_ALWAYS`), it writes the global uniforms through the sink: `mode_time` from `machine.mode_time` (which stops under the Menu), and `actor_rim_color`/`actor_rim_strength` from the stage's current blended values.
- **The sink.** `GlobalUniformSink` is an interface. The production sink calls `RenderingServer.global_shader_parameter_set()`, and the test sink records values. `global_shader_parameter_get()` returns null at runtime on 4.7.2 (observed), so nothing, tests included, may read the globals back from the engine.
- **One door:** the Director calls only `stage.bind_profiles()`, `stage.apply_profile()` and `stage.set_ambient_paused()`, and reads `profile_id` and the current rim values. The owning mode calls only `stage.request_profile()`. The stage writes its own children.

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
  - **Size and aspect.** `keep_aspect = KEEP_HEIGHT` **always**. Never `KEEP_WIDTH` under `PROJECTION_FRUSTUM`: on 4.7.2 the renderer then treats `size` as the near-plane width (the image zooms by 16/9 below 16:9), and `get_camera_projection()`/`unproject_position()` ignore `keep_aspect` in FRUSTUM mode while the GPU honours it, so the CPU and GPU projections disagree (probed, review 6). `size = h_near = 2 · near · tan(battle_fov / 2) · max(1, (16/9) / aspect)`, recomputed on the viewport's `size_changed`. So at 16:9 and wider the vertical view is `battle_fov`, and below 16:9 (Steam Deck's 16:10, 4:3) the vertical view widens so the 16:9 horizontal view is kept (the GDD's `F_v_eff`).
  - **Lens shift.** `h_near = size` (always `KEEP_HEIGHT`). The lens shift places the horizon at the stage's `horizon_frac`: `frustum_offset.y = −(0.5 − horizon_frac) · h_near` (sign verified on 4.7.2: +y moves the image down).
  - **Hit-punch.** The punch adds `(px_x · h_near / H, −px_y · h_near / H)` to `frustum_offset`, where `(px_x, px_y)` is the GDD's `hit_punch` offset in screen pixels with y down. With these signs the image moves by `(−px_x, −px_y)` on screen (+x in `frustum_offset` moves the image left; probed). The GDD's punch is a direction-agnostic jolt, so the mapping is fixed here and pixel-exact.
  - **Never moves in a fight.** The camera's position, rotation and `near` never change in a fight, and `size` changes only on a window resize. `h_offset`/`v_offset` stay 0, and a translation shake is forbidden: it moves near and far depths by different amounts.
  - **CPU projection.** `SpriteProjection`'s `CameraState` builds its matrix as `Projection.create_frustum_aspect(size, aspect, frustum_offset, near, far, false)`, never from `Camera3D.get_camera_projection()`. No test uses `unproject_position()` on a FRUSTUM camera.
- **Overworld:** a perspective follow camera (`FollowCamera`) at a fixed yaw and pitch, moving position only, with `keep_aspect = KEEP_HEIGHT` and its `fov` widened below 16:9 by the same `F_v_eff` rule (Step 1 probes the perspective path at 16:10 and 4:3). The GDD's `follow_camera` formula, including `F_v_eff`, is implemented exactly. The Overworld ADR decides what it follows.
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
- **Backend: Vulkan required, no fallback** (user decision, 2026-10-22). `rendering/rendering_device/driver.windows = "vulkan"` (also the 4.7.2 default, probed) and `rendering/rendering_device/driver.linuxbsd = "vulkan"`. **Both fallbacks are off**: the D3D12 fallback (`rendering/rendering_device/fallback_to_d3d12`) and the OpenGL3/Compatibility fallback (`rendering/rendering_device/fallback_to_opengl3`), so the game never runs on a look nobody signed off with un-warmed pipelines. Both settings exist on 4.7.2 and **default to true** (probed 2026-10-22), so `project.godot` must set both to `false` explicitly; AC-47 checks it. A PC that can't create a Vulkan device gets **the engine's own Vulkan-failure alert** (shown before any script runs, so it can't be customised from GDScript) and the game exits; Step 1 records the alert's actual text, and the store page states the Vulkan requirement.
- **Steam Deck build: a native Linux export** (Godot's `Linux` export preset, x86_64), not the Windows build under Proton. It runs Vulkan natively, keeps one backend on every target, and its Shader Baker cache is built for that export. The test matrix is Windows desktop + Steam Deck native. Targets (`project.yaml` `platform`): Windows on a GTX 1080-class GPU with 8 GB RAM, and Steam Deck (SteamOS, 1280×800).

All are set in `project.godot`, and AC-47 checks them.

**11. Nothing compiles in play: the measured contract and Boot warm-up.**
- **The contract.** After Boot, no preset switch, blend, discrete parameter change, or cycle through a mode's states compiles a rendering pipeline (GDD `lighting_blend`, ruling 5). It is **measured**, not assumed. AC-64 records every `Performance.PIPELINE_COMPILATIONS_*` monitor (canvas, mesh, surface, draw, specialization; probed on 4.7.2) before and after a scripted state cycle, from an empty shader cache.
- **What "empty shader cache" means.** Both engine caches are on by default on 4.7.2 (`rendering/rendering_device/pipeline_cache/enable` and `rendering/shader_compiler/shader_cache/enabled`, both true; probed). Before an AC-64 run, the harness deletes:
  - the engine's Vulkan pipeline cache files in the project's user data directory (`user://`; the exact subfolder and file names on 4.7.2 are confirmed in Step 1 and written into P-15);
  - the project's `.godot/shader_cache/` on a development run.
  
  Both settings stay at their shipped values (true); the run measures the contract as players get it, minus the warm cache. **Driver-level caches are invisible to the counters** and are not cleared by the harness: the NVIDIA driver cache on the desktop, Mesa/RADV's on-disk cache, and Steam's Fossilize pre-cache on the Steam Deck. They can hide a compile from the frame-time spike guard but never from the counters, which count the engine's pipeline requests, so the counters stay the measure. P-15 records which driver caches were present on each run.
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
- **Boot warm-up.** Behind the Boot screen, in the **main viewport** (pipelines are keyed by framebuffer format and MSAA, so warming in a differently configured `SubViewport` warms the wrong pipelines), Boot renders a warm-up stage. That stage draws every shipped sprite, set, sky-card and VFX material under every (mode, profile) combination's compiling parameters, for at least 2 frames each, **and every canvas material the game uses in play** (the Menu backdrop blur, the wipes, the retry flash and its capped variant, the Defeat card), so AC-64's canvas counter stays at zero on the first Menu open.
- **What the counters can't see.** Turning glow on and switching the tonemapper left the counters at 0 on 4.7.2 (probed), so post-effect pipelines may sit outside them. AC-64 therefore adds a negative control (one Environment toggle, expected to register or be caught by the second check) and a frame-time spike guard: with `RenderingServer.viewport_set_measure_render_time` on, no frame of the scripted state cycle exceeds `frame_time_worst_ms` (33 ms). Shader Baker (4.5) runs at export as well. The export option isn't sourceable here; it is verified at the first export.

**12. `FlashGate` (a service under `GameRoot/Services`).** It implements the GDD's `flash_gate`:
- **Clock.** A real-time clock is injected (integer microseconds in tests), so the Menu never resets it.
- **Declarations.** Each source has a `FlashSourceDecl` resource holding:
  - its class (gated, reserved, area-exempt or swing-exempt);
  - its clock: `MODE`, `REPLAY` or `REAL`;
  - its transitions: offset on that clock, direction, general or red, and area as a share of a 10° window;
  - its capped variant's declared frames: peak luminance swing **and** peak red change (both must be below the transition thresholds), or area below `flash_area_min`;
  - for area-exempt sources, its largest area.

  They are validated at boot (§9), including every scripted reserved sequence at 1×, the largest `battle_speed_mult` and the largest `ff_mult`.
- **Requests.** One signature, in Key Interfaces and here:
  - `request(source_id: StringName, clock: Callable, rate: float) -> int` books a gated source's transitions at `t_land = now + (o − clock.call()) / rate` iff no closed one-second window would then hold more than `flash_rate_max` flashes, counted as transitions that oppose their predecessor. It returns a booking handle, or `-1` when refused (the caller plays the capped variant). With Reduce Flashing On it always returns `-1`.
  - `set_rate(handle, rate: float) -> bool` re-books the handle's unlanded transitions at the new rate (`0` while the Menu freezes the source's clock: they are held unbooked). It returns false when the re-booking would exceed the limit; the gate then drops only the not-yet-started transitions and the caller finishes in the capped variant from that frame. **Closing transitions** (those ending an already-landed opposite transition of the same handle) are never dropped and re-book with reserved priority, so a raised screen always returns to rest (GDD `flash_gate`). Frozen transitions count as pending at their resume-time landing for requests made during the freeze. `request()` takes the source's known rate schedule (wind-up at speed, hold at 1×) from its `clock` owner, so only unscheduled changes, including a `dt_max`-clamped frame, need `set_rate`. The Battle mode calls it for replay-clock sources on `latch_changed` and on speed-setting changes, and every mode calls it for its mode-clock sources on `overlay_opened/closed(MENU)`.
  - `book_reserved(source_id, clock, rate)` books unconditionally, and `set_rate` on a reserved handle always succeeds.
  - `cancel(handle)` removes a booking's unlanded transitions. A source that is thrown away before it finishes must cancel its booking. The Battle mode cancels every replay-clock booking it holds next to each `cancel_pending_replay()` call (Retry, exit), so the discarded beats' flashes never count against `flash_rate_max` and never cap the retry flash.
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
func setup(sprite_frames: SpriteFrames, config: PresentationConfig) -> void   # own ShaderMaterial; stop() here ONCE, never per frame
func show_frame(animation_id: StringName, facing: StringName, mirrored: bool, frame: int) -> void
#   sets animation (only if changed), THEN frame (or set_frame_and_progress), AND frame_tex in one call;
#   stop() and an animation assignment both reset frame to 0 (probed 4.7.2), hence the order (§1)
#   picks <id>_<facing>_mirrored for no_mirror animations
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
func bind_profiles(resolver: Callable) -> void      # Director only, on mode_entered; resolver(id) -> LightingProfile or null
func request_profile(id: StringName, blend_time: float, clock: Callable = Callable()) -> void   # owning mode only
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
func setup(real_clock: Callable, config: PresentationConfig, decls: Dictionary[StringName, FlashSourceDecl], settings: FlashSettings) -> void
#   FlashSettings: a RefCounted interface with reduce_flashing() -> bool; prod reads the Settings service, tests inject a stub
func request(source_id: StringName, clock: Callable, rate: float) -> int   # handle, or -1 = refused (play capped)
func set_rate(handle: int, rate: float) -> bool       # re-book unlanded transitions; false = dropped, switch to capped now
func book_reserved(source_id: StringName, clock: Callable, rate: float) -> int
func cancel(handle: int) -> void                      # drop unlanded transitions of a discarded source
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
- **A custom vertex path** (clip-space `POSITION`) must be maintained (Verification Required item (10), verified 2026-10-22).
- **Every world shader author** must use `mode_time`, not `TIME`.
- **Boot does more work:** it renders a warm-up stage, which lengthens Boot.

## Risks
- **The clip-space quad misbehaves** under `frustum_offset` or in the pitched card case. *Retired 2026-10-22*: Verification Required item (10) was probed pixel-exact, with upright-card depth, level and pitched. Residual: the §2 fallback (per-frame `pixel_size`) stays documented in case the Step 1 stage shows a regression on the Steam Deck.
- **The `frustum_offset` sign or units differ** from §6. *Retired 2026-10-22*: probed on 4.7.2 (near-plane units; +y moves the image down, +x left). Residual: Step 1 re-measures against `battle_framing`'s `y_h` at 16:9 and 16:10.
- **A lighting parameter compiles when it was expected not to.** *Mitigation*: the counters (§11) catch it in Step 1, and the warm-up list grows.
- **The glow-input hook is unavailable.** *Mitigation*: AC-32's glow clause stays Pending, and the glow threshold is tuned by eye with a conservative margin.
- **Shader Baker's export option differs.** *Mitigation*: verified at the first export; the Boot warm-up alone already meets the contract on the development PC.
- **Thin features shimmer in the set's shadow maps.** *Mitigation*: per-stage shadow bias tuning in Step 1.

## GDD Requirements Addressed

TR IDs from `docs/architecture/tr-registry.yaml`, assigned by `/architecture-review` on 2026-10-22 (back-fill map in `architecture-review-2026-10-22.md`).

| TR-ID | GDD System | Requirement | How This ADR Addresses It |
|-------|------------|-------------|--------------------------|
| TR-presentation-001 | sprite-camera-presentation.md | Rule 2: every texel is `T × T` px at every depth; screen-facing, pixel-snapped quads; nearest filtering; never rotated or rescaled | §1, §2 (`SpriteProjection`, the clip-space quad) |
| TR-presentation-002 | sprite-camera-presentation.md | Rules 2 and 4: upright-card occlusion under pitched cameras; a level shift-lens battle camera that never moves, rotates, zooms or changes FOV | §2 (upright-card depth), §6 (`PROJECTION_FRUSTUM`, `frustum_offset`) |
| TR-presentation-003 | sprite-camera-presentation.md | Rule 1: actors lit only by their key, rim and tagged practicals; a rim never on the outline; per-sector `read_order` | §2 (`ambient_light_disabled`, cull masks, rim texel ring), §3 light rig |
| TR-presentation-004 | sprite-camera-presentation.md | One lighting signature per state, applied before the reveal; blends never pop | §4 (Director applies on `mode_entered`), §3 `request_profile` blends from the captured current light |
| TR-presentation-005 | sprite-camera-presentation.md | Rule 6: the dusk flood on a sky card always in frame; `set_brightness_boss` < 1; the takeover on the replay's clock; missing boss preset = boot error | §3 (`SkyCard`; `request_profile` with a clock), §5 (sky fields), §9. The takeover clock itself is ADR-0006 |
| TR-presentation-006 | sprite-camera-presentation.md | Fixed per-mode cameras; overworld follow camera; aspect rules | §6 (`KEEP_HEIGHT`, widened `size` below 16:9, follow camera) |
| TR-presentation-007 | sprite-camera-presentation.md | Rule 8: the punch as a whole-pixel shift of every depth; HUD never moves; honours Screen Shake / Reduce Motion | §6 (punch on `frustum_offset`) |
| TR-presentation-008 | sprite-camera-presentation.md | The Menu freezes the world; no shader reads `TIME` | §4 (`mode_time` global via the sink), §7, §1 ambient frames on mode time. Mode time itself is ADR-0002 |
| TR-presentation-010 | sprite-camera-presentation.md | One beat clock drives sprite frames, the punch and beat-synced sound | §1 (beat-driven frames from ADR-0006's clocks; call order), §6 punch. The clock itself is ADR-0006 |
| TR-presentation-014 | sprite-camera-presentation.md | Rule 10: boot validation of required animations, `impact_frame`, `land_frame`, `intro` length, boss presets, knob ranges | §9 (validators via ADR-0004's `register_record_validator`) |
| TR-presentation-015 | sprite-camera-presentation.md | Rule 13: one flash gate for every large-area source, booking at landing | §12 (`FlashGate`, `FlashSourceDecl`) |
| TR-presentation-016 | sprite-camera-presentation.md | Nothing compiles a pipeline in play, measured on the counters | §11 (counters, defined cache state, warm-up in the main viewport, Shader Baker) |
| TR-presentation-017 | sprite-camera-presentation.md | Rendering constraints: native scale, SDR, no screen-space AA, Vulkan with no fallback, native Linux Deck build | §7, §10 |
| TR-presentation-018 | sprite-camera-presentation.md | Battle performance: 300 3D + 100 canvas draw calls; p99 ≤ 16.6 ms, worst ≤ 33 ms on GTX 1080 / Steam Deck | Performance Implications; Validation Criteria (P-14) |
| TR-presentation-019 | sprite-camera-presentation.md | Rule 12: one blob shadow per actor; only the set light casts | §2 (`cast_shadow` OFF), §3 (`SetLight`, blob shadows) |
| TR-presentation-020 | sprite-camera-presentation.md | Two facings with mirroring; per-animation `no_mirror`; fallbacks keep `no_mirror` | §1 (Facings), §9 |
| TR-presentation-021 | sprite-camera-presentation.md | All knobs and presets in presentation data, validated at load | §5 (`PresentationConfig`, `LightingProfile`), §9. The replay knobs are ADR-0006 §9 |
| TR-presentation-022 | sprite-camera-presentation.md | Six comfort settings applied live | **Partial:** §6 (Screen Shake, Reduce Motion), §12 (Reduce Flashing via `FlashSettings`), Reduce Blur in §3 DOF. The settings service itself awaits the Save/Load & Settings ADR |
| TR-presentation-023 | sprite-camera-presentation.md | Acceptance Criteria [C]: the deterministic capture tool | §13, Migration Step 1c |
| TR-presentation-024 | sprite-camera-presentation.md | Rule 11: faction colour only on sky, set and fill during a boss takeover; the flood never tints the squad | §2, §3 (actors take no ambient, fill or set light), §5 |
| TR-gamestate-007 | game-state-scene-flow.md | Transition flashes booked through the flash gate; capped variant on refusal | §12 (`FlashGate` injected into ADR-0002's machine) |
| — (no TR) | art-bible.md §1–§2 | One pixel scale; per-state lighting signatures; the boss flood | §1–§5 |
| — (no TR) | game-state-scene-flow.md | Lighting on `mode_entered`; Rule 10 (Menu stops mode time) | §4, §7 |
| — (no TR) | content-data-definitions.md | Rule 3: art by asset ID | §5 sprite-set table, §9 |
| — (no TR) | systems-index.md | Top Presentation risk: mixed pixel scales / `Sprite3D` filtering | §2 makes mixed scale impossible; Step 1 verifies |

## Performance Implications
- **CPU:** one `SpriteProjection.screen_rect()` per sprite per frame (about 8 in a battle) and a few uniform writes. The Director writes 3 globals per frame. Negligible.
- **GPU / draw calls:** actors cast no shadows, so there is no actor shadow pass. Per battle: about 8 actor draws, 8 blob shadows, 1 sky card, the diorama (with `SetLight`'s cascades) and VFX. `FillLight` casts nothing. DOF and glow are the main GPU costs, measured in P-14.
- **Budget (user decision 2026-10-22, `project.yaml` `performance`):**
  - **Draw calls in a battle:** at most **300 for all 3D passes** (including `SetLight`'s shadow cascades) plus at most **100 for canvas/HUD**, counted separately (`draw_call_limit: 400` total). The earlier 150 was below the estimated 190–275 and is withdrawn; re-measure on the Step 1 stage.
  - **Frame time:** p99 ≤ **16.6 ms** and worst frame ≤ **33 ms** over a scripted battle (P-14).
  - **Target hardware:** a GTX 1080-class desktop GPU with 8 GB system RAM at **1920×1080**, and **Steam Deck at 1280×800** (16:10, `T = 2`). These two are the binding cases. 2160p is measured and reported on the desktop target, but it does not gate.
  - **Memory:** no ceiling is committed yet (`performance.memory_ceiling_mb` unset); P-14 reports peak RAM and VRAM so one can be set.
- **Memory:** `SpriteFrames` per character (small); the detached Overworld diorama stays resident during battles (ADR-0002).
- **Load time:** Boot's warm-up stage adds a one-off cost at boot, measured in P-15. Battle stages load inside ADR-0002's swap budget.
- **Network:** none.

## Migration Plan
No 3D presentation code exists; the battle HUD and demos are 2D `Control` scenes and are unaffected until the Turn Battle presentation story.
1. **Early technical test**, as a spike in `prototypes/sprite_camera_spike/`, not `src/`. One `CharacterSprite`-equivalent with placeholder art in a small lit diorama, a level shift-lens battle camera, a pitched overworld camera, a sky card, and the `battle`, `boss_*` and `camp` profiles. It settles Verification Required items (12)–(16) ((10) and (11) were verified on 2026-10-22), and sets `battle_fov`, `h_cam`, `horizon_frac`, slot depths and `humanoid_height_px`. Retained screenshots go in `production/qa/evidence/`, from a windowed run. The spike also runs **on a Steam Deck as a native Linux export** at 1280×800: it records frame time (p99 and worst) with MSAA 2×, DOF and glow on, peak RAM and VRAM (the Deck shares 16 GB), the 16:10 framing, and the Vulkan-failure alert text and fallback setting names. The Deck is the binding device, so a miss there is found in the spike, not at the battle-stage story.
   - **1b.** Publish the confirmed compiling-parameter list in §11, and the `frustum_offset` sign in §6, in this ADR.
   - **1c. Build the capture tool** (`tools/capture/presentation_capture.gd`), **as its own story**, from the test plan's P-09: explicit `SubViewport` settings, the ID pass, the shadow mask, the unlit-albedo mode, UI-alone, and the glow-input hook, or a recorded "Pending" if item (15) fails. The flash analyser (P-13) is a separate story. Until 1c is Done, no story that ships a [C]-measured feature can close on that clause.
2. ~~Assign TR IDs, back-fill and Accept.~~ Done 2026-10-22: `/architecture-review` assigned the TR IDs, they are back-filled, and this ADR was Accepted after ADR-0002 → ADR-0004 → ADR-0003 → ADR-0006 (ADR-0006's dependency on this ADR was moved to its Enables row, which cut the cycle). The user ratified D1–D4 on 2026-10-22 (D1 with stars).
3. **Requires ADR-0004's implementation.** Build test-first in `src/presentation/`: `SpriteProjection`, `CharacterSprite`, `DioramaStage`, the sky card, `PresentationDirector` with `GlobalUniformSink`, `LightingProfile`, `PresentationConfig` and its validation, `FlashGate`, the validators, and the Boot warm-up.
4. With ADR-0002's Battle mode story and ADR-0006: the battle stage wraps `BattleCore` with sprites, drives frames from the controller's clocks, and keeps the existing `BattleHud` as an overlay `Control`.
5. With the Overworld ADR: the follow camera, `occupied_*`/`dungeon` profiles and region dioramas.

## Validation Criteria
- **Step 1 evidence:** screenshots (battle, one boss takeover, camp; near and far rows; a pitched overworld sprite against a wall) retained in `production/qa/evidence/` with lead sign-off.
- **`SpriteProjection` unit tests** (P-03):
  - `T` at 720, 800 (Steam Deck), 900, 1080, 1440 and 2160;
  - the rectangle's size and rounding, including odd `frame_w · T` (left edge `x_a − floor(frame_w·T/2)`);
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
- **The compile contract:** P-15 (GDD AC-64), with its negative control and the frame-time spike guard.
- **Performance acceptance** (P-14, GDD AC-31): on the GTX 1080-class desktop at 1920×1080 and on Steam Deck at 1280×800, a scripted boss battle (reveal, takeover, a full round of beats with VFX, Victory) holds p99 frame time ≤ 16.6 ms and no frame over 33 ms, with ≤ 300 3D and ≤ 100 canvas draw calls on every frame. A failure on either device blocks acceptance of the story that ships the battle stage.
- **Aspect:** at 1280×800 and 1024×768, `size` equals `2·near·tan(battle_fov/2)·(16/9)/aspect`, `keep_aspect` is `KEEP_HEIGHT`, and a rendered marker lands on the pixel `SpriteProjection` predicts (the KEEP_WIDTH regression, review 6).
- **Backend:** a launch with Vulkan unavailable (forced in a test build) shows the engine's Vulkan-failure alert and never starts on D3D12 or OpenGL3, with both fallback settings set to `false` in `project.godot` (names probed on 4.7.2).
- **Retry light:** an integration test of a boss Retry, uncapped and capped: the Director's `mode_entered` on the Battle → Battle row applies nothing, and the light equals the boss end state (uncapped) or blends from Defeat over `blend_defeat` (capped).

## Related
- Depends on: `docs/architecture/adr-0001-content-data-storage-format.md` (Accepted), `adr-0002-game-state-scene-flow.md`, `adr-0004-content-boot-ordering.md` and `adr-0006-battle-replay-ownership.md` (all Accepted 2026-10-22).
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
- 2026-10-22 — **Review of revision 2** (godot-specialist, probed 4.7.2 windowed + headless; technical-director TD-ADR). godot-specialist: CONCERNS. TD-ADR: REVISE (a targeted pass, not a rewrite). Every review-5 tracked item landed.
  - Probed and VERIFIED: `PROJECTION_FRUSTUM` + `frustum_offset` (near-plane units; +y moves the image down) and the §6 lens-shift sign under `KEEP_HEIGHT`; the clip-space quad is pixel-exact, with upright-card depth (level and pitched); `RENDERING_INFO_PIPELINE_COMPILATIONS_*`; runtime global uniforms; `SubViewport` defaults; Vulkan is the 4.7.2 default driver (engine-reference `modules/rendering.md` is wrong).
  - **[BLOCKING] `KEEP_WIDTH` under `PROJECTION_FRUSTUM`** (§6 L154–158, Validation L499): the renderer treats `size` as the near-plane width (zooms 16/9 below 16:9), and `get_camera_projection()`/`unproject_position()` ignore `keep_aspect` in FRUSTUM mode while the GPU honours it. Fix: always `KEEP_HEIGHT`; below 16:9 set `size = 2·near·tan(fov/2)·(16/9)/aspect` on `size_changed`; `CameraState` builds `Projection.create_frustum_aspect(...)`.
  - **[BLOCKING] Stage → Director profile path** (L120–123, L130, L366): the stage holds neither the config nor the Director. Fix: `bind_profiles(resolver)` on `mode_entered`, or a `profile_requested` signal the Director connects.
  - **[BLOCKING] Same-mode `mode_entered(BATTLE)` overwrites the boss/Retry light** (L121, L126 vs ADR-0002 §7, ADR-0006 §5 step 3). Fix: stages enter on `battle`; the Battle mode requests `boss_<faction>` on `hold_started(TAKEOVER_FULL)` with the hold clock; the Director skips its apply on a same-mode row.
  - **[BLOCKING] No performance acceptance criterion** (L467–471; architecture.md L237–245). TD proposes 300 3D draw calls (incl. SetLight cascades) + ≤ 100 canvas, p99 ≤ 16.6 ms and worst ≤ 33 ms at 1080p and 2160p. User decision, with target hardware and a VRAM budget recorded in `project.yaml`.
  - Recommended: the `FlashGate.request` signature (L212 vs L307); reserved-sequence validation in §9; the warm-up omits canvas pipelines; the counters miss post-effect compiles (add an Environment-toggle negative control and a frame-time spike guard); NDC is y-down, set `VERTEX`/`NORMAL`, `FRAGCOORD` UVs under pitch; corners from `VERTEX`/`VERTEX_ID` not `UV` (atlas region UVs), plus `custom_aabb`; sky card `unshaded, fog_disabled`, covering the frame at max shift + punch; a Vulkan fallback policy; state the punch direction; typed injectable settings for `FlashGate.setup`; Core never references `BattleReplayController`; accept together with ADR-0006 (circular dependency); half-pixel centring for odd `frame_w·T` (GDD review 6, L92).
- 2026-10-22 — **Revision 3**, answering the review of revision 2 (all four blockers) and the user's decisions:
  - **Camera:** `KEEP_HEIGHT` always; below 16:9, `size` is widened by `(16/9)/aspect` on `size_changed`; the CPU matrix comes from `Projection.create_frustum_aspect`; the punch direction is stated; the Overworld also stays on `KEEP_HEIGHT` with `F_v_eff`.
  - **Profile path:** `bind_profiles(resolver)` from the Director on `mode_entered`. Every battle stage enters on `battle`. The Battle mode requests `boss_<faction>` on `hold_started(TAKEOVER_FULL)` with the hold clock, and on Retry during SWAP (blend 0, or `blend_defeat` when `GameStateMachine.is_transition_flash_capped()`). The Director skips its apply on a same-mode row. Core never references `BattleReplayController`.
  - **Performance:** a budget and acceptance criterion (300 3D + 100 canvas draw calls; p99 ≤ 16.6 ms, worst ≤ 33 ms; GTX 1080-class at 1080p and Steam Deck at 1280×800).
  - **Backend:** Vulkan required, D3D12 fallback off, and a clear error without Vulkan.
  - **FlashGate:** one signature. Transitions sit on the source's own clock and `set_rate` re-books them. Capped variants are bounded on red as well as luminance. Reserved sequences are validated at every speed, and settings are typed (`FlashSettings`).
  - **Shader specifics** from the probes: NDC y-down, corners from `VERTEX_ID`, `VERTEX`/`NORMAL` written, `FRAGCOORD` UVs under pitch, and `custom_aabb`.
  - **Sky card:** `unshaded, fog_disabled`, covers the frame at max shift plus punch, and draws the GDD's stars.
  - **Other:** canvas materials added to the warm-up, a frame-time spike guard for post-effect compiles, odd-width centring, and acceptance together with ADR-0006.
  - **Pending:** a short re-review.
- 2026-10-22 — **Short re-review of revision 3** (TD-ADR): ACCEPT WITH CONDITIONS. All four blockers CLOSED. The size formula is confirmed equal to the GDD's `F_v_eff`, and the CPU/GPU agree. Conditions folded in during the same pass:
  - the capped-Retry blend starts at SWAP (§3);
  - the OpenGL3 fallback is off too, with `driver.linuxbsd` named;
  - "engine's Vulkan-failure alert" replaces the custom dialog;
  - the Steam Deck build is a native Linux export (autonomous pick of the recommended option);
  - Step 1 runs on the Deck;
  - `FlashGate.cancel(handle)` is added for discarded replay beats;
  - `decls` is typed.
  
  Next: `/architecture-review`, then acceptance together with ADR-0006 after ADR-0004 → ADR-0002.
- 2026-10-22 — **`/architecture-review` fixes** (`architecture-review-2026-10-22.md`), no decision change:
  - **E1:** `stop()` and assigning `animation` both reset `frame` to 0 (probed). §1 and Key Interfaces now pin the order: `stop()` once in `setup()`, then `animation` before `frame` (or `set_frame_and_progress()`).
  - **E2:** §11 defines the AC-64 cache state: the engine's Vulkan pipeline cache in `user://` and `.godot/shader_cache/` are deleted, both cache settings stay at their shipped `true`, and driver caches (NVIDIA, Mesa/RADV, Steam Fossilize) are named as invisible to the counters.
  - **E3:** Verification Required items (10) and (11) are marked VERIFIED, matching §6 and the review of revision 2. The fallback, Risks, Negative and Migration Step 1 references now agree.
  - **TR IDs back-filled** into GDD Requirements Addressed: TR-presentation-001..008, 010, 014..024 (022 partial, pending the Save/Load & Settings ADR); TR-gamestate-007.
  - **The dependency cycle** was cut on ADR-0006's side (ADR-0005 moved to its Enables row).
  - **E4 (advisory):** §10 now says both fallback settings exist, default to true (probed) and must be set to false explicitly.
  - Advisory E5 (`ALPHA_SCISSOR` discards in the depth prepass, so "early-z stays on" is overstated) and E10 (Shader Baker plus global uniforms on a Linux export built from Windows) are not yet folded in.
- 2026-10-22 — **Accepted** by the user, last in the order ADR-0002 → ADR-0004 → ADR-0003 → ADR-0006 → ADR-0005 (explicit instruction). No stories were Blocked on this ADR.
- 2026-10-22 — `/architecture-review` (`architecture-review-2026-10-22c.md`), godot-specialist **E4**: the texel formula now names its source, `get_viewport().size.y` (full window height under ADR-0008's refit). Wording only; T is unchanged.
