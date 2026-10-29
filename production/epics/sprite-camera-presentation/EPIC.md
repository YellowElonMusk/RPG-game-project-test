# Epic: Sprite & Camera Presentation

> **Layer**: Core
> **GDD**: design/gdd/sprite-camera-presentation.md
> **Architecture Module**: Sprite & Camera Presentation (with FlashGate; BattleReplayController's display side via ADR-0006)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories sprite-camera-presentation`

## Overview

This epic builds how the game world is shown, so that the Overworld Exploration & Encounters epic and the 3D battle stage have something to stand on. It covers:

- pixel-art `CharacterSprite`s at one constant texel scale, foot-anchored, nearest-filtered and pixel-snapped, standing in lit low-poly `DioramaStage`s;
- fixed per-mode cameras: a level shift-lens battle camera (Dragon Quest / Chrono Trigger framing), a pitched overworld follow camera, and fixed camp and title framing;
- one lighting signature per game state, applied before each transition reveals the mode, with a sky card and the boss takeover flood;
- the `mode_time` global that freezes the world under the Menu;
- the global `FlashGate` that already backs Game State's retry flash through `FlashGatePort`;
- the hit-punch, blob shadows, two-facing mirroring, boot validation of presentation content, the pipeline warm-up, and the capture tool the capture-measured acceptance criteria need.

ADR-0005's Migration Plan sets the order: the windowed spike (Step 1, verification items 12–16), then the capture tool as its own story (1c), then the test-first `src/presentation/` build (Step 3, after ADR-0004's implementation, which exists), then the battle stage with ADR-0006 (Step 4), and the overworld profiles and follow camera with ADR-0012 (Step 5). Engine risk is HIGH: rendering changed in 4.5, 4.6 and 4.7, and five verification items are still open.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: Sprite & Camera Presentation | `CharacterSprite` driven by a shader that owns texture, cut-out, filter and billboarding; `DioramaStage` per 3D mode; `PresentationDirector` and `GlobalUniformSink`; `LightingProfile`/`PresentationConfig` data; fixed cameras on `frustum_offset` with `KEEP_HEIGHT`; sky card; `FlashGate`; boot validators; pipeline warm-up; capture tool | HIGH |
| ADR-0006: Battle Replay Ownership | `BattleReplayController` owns the replay queue, beat clocks, latch and display snapshots that presentation reads; presentation never runs its own beat timers | LOW |
| ADR-0008: UI Framework | Menu input guard (safe default focus, refusal) and the live UI comfort settings | HIGH |
| ADR-0009: Save/Load & Settings | The settings service that delivers the six comfort settings live | LOW–MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-presentation-001 | One on-screen texel scale T = max(1, floor(H/360)) for every sprite at every depth; screen-facing quads foot-anchored and snapped to whole pixels; nearest filtering; never rotated or rescaled | ADR-0005 ✅ |
| TR-presentation-002 | Occlusion as an upright card at the foot anchor under the pitched Overworld and Camp cameras; a level shift-lens battle camera that never moves, rotates, zooms or changes field of view | ADR-0005 ✅ |
| TR-presentation-003 | Actors lit only by their own key, a rim on the texel ring inside the outline, and tagged practicals; never ambient, fill or set light; per-sector local read_order contrast on reference captures | ADR-0005 ✅ |
| TR-presentation-004 | One lighting signature per state, already applied when the transition reveals the mode; in-mode blends via lighting_blend start from the captured current light and never pop | ADR-0005 ✅ |
| TR-presentation-005 | Boss takeover: faction dusk flood on a backdrop sky card (sky share, swatch match, neon horizon, stars), set_brightness_boss below 1.0, driven by the replay's takeover clock; a missing boss preset is a boot error | ADR-0005 ✅, ADR-0006 ✅ |
| TR-presentation-006 | Fixed per-mode cameras: overworld follow camera with dead zone, tau, ground-footprint clamp, dt_max and snap on teleport; aspect rules (16:9 horizontal view kept below 16:9, more set at 21:9) | ADR-0005 ✅ |
| TR-presentation-007 | Hit-punch is a whole-pixel shift of every depth, scaled with window height, HUD never moves, at most one per beat, honours Screen Shake and Reduce Motion | ADR-0005 ✅ |
| TR-presentation-008 | The Menu freezes the world: sprite frames, blends, punch, ambient motion and the replay all run on Game State's mode time; no shader reads TIME | ADR-0005 ✅ |
| TR-presentation-009 | Battle outcomes replayed beat by beat (wind-up, impact, unscaled reaction hold, number); every beat lasts at least beat_min; no beat skipped on slow frames; end-of-fight holds before the outcome report | ADR-0006 ✅ |
| TR-presentation-010 | One beat clock drives beat-driven sprite frames, the hit-punch and beat-synced sound (beat_impact); no beat-driven animation runs on its own timer | ADR-0005 ✅, ADR-0006 ✅ |
| TR-presentation-011 | One-level replay latch (Confirm, fast_forward or indicator click), Cancel clears; Faster battle animations and Speed up boss entrances settings; ineffective presses refused visibly; three-state replay indicator; no input buffering; presses count only after the reveal | ADR-0006 ✅ |
| TR-presentation-012 | Menu input guard: command menu, target selection, Defeat Prompt and results open with safe default focus and refuse every menu action for input_guard with visible and audible refusal; held inputs never carry in | ADR-0008 ✅ |
| TR-presentation-013 | HUD reads HP, MP, status, round and floating numbers only through the replay's displayed state; Retry, Retreat, Quit and freeing cancel the replay and resync a clean display | ADR-0006 ✅ |
| TR-presentation-014 | Boot validation of presentation content: sprite_set_id resolves, required animations per set and facing, impact_frame, land_frame, boss intro length, duplicate move keys, missing boss presets, chained knob ranges; battle stages validated on load | ADR-0005 ✅ |
| TR-presentation-015 | One global flash gate for every large-area luminance source (presentation, Game State, UI): gated, reserved, exempt-by-area and exempt-by-swing classes; landing-time booking on each source's own clock; capped variants; flash_rate_max at most 3 per second; reserved sequences proven at boot | ADR-0005 ✅ |
| TR-presentation-016 | Nothing compiles a rendering pipeline in play after Boot warm-up, measured on the engine's pipeline-compilation counters | ADR-0005 ✅ |
| TR-presentation-017 | Rendering constraints: native scale, SDR output, no screen-space AA, Vulkan pinned with no fallback on every target including a native Linux Steam Deck build | ADR-0005 ✅ |
| TR-presentation-018 | Battle performance: at most 300 3D plus 100 canvas draw calls; p99 frame at most 16.6 ms and worst at most 33 ms on a GTX 1080-class desktop at 1080p and on Steam Deck at 1280x800 | ADR-0005 ✅ |
| TR-presentation-019 | Blob ground shadow per actor only; actors cast no light shadows; only the set light casts; blob colour from the lighting state, never faction colour | ADR-0005 ✅ |
| TR-presentation-020 | Two authored facings with mirroring; per-animation no_mirror; optional animations fall back in the same facing and never break no_mirror | ADR-0005 ✅ |
| TR-presentation-021 | All presentation knobs and lighting presets live in presentation data, never code, with load-time validation of chained ranges | ADR-0005 ✅, ADR-0006 ✅ |
| TR-presentation-022 | Six comfort settings (Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur, Reduce Flashing, Reduce Motion) read from the settings service and applied live | ADR-0005 ✅, ADR-0008 ✅, ADR-0009 ✅ |
| TR-presentation-023 | A deterministic capture tool for the [C] capture-measured acceptance criteria (explicit SubViewport settings, ID pass) | ADR-0005 ✅ |
| TR-presentation-024 | Faction colour only on the sky, set and fill during that faction's boss takeover (and future occupation stages); never on actors, neutral states, fades or UI; every boss stage frames a tagged faction shape | ADR-0005 ✅ |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/sprite-camera-presentation.md verified
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
