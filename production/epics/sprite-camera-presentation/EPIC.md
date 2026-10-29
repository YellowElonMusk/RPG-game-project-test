# Epic: Sprite & Camera Presentation

> **Layer**: Core
> **GDD**: design/gdd/sprite-camera-presentation.md
> **Architecture Module**: Sprite & Camera Presentation (with FlashGate; BattleReplayController's display side via ADR-0006)
> **Status**: Ready
> **Stories**: 74 stories — see the table below

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


## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Windowed engine spike settles sprite-shader and camera verification on 4.7.2](story-001-windowed-engine-spike.md) | Visual/Feel | Ready | ADR-0005 |
| 002 | [The capture tool renders the deterministic passes the \[C\] acceptance criteria measure](story-002-capture-tool.md) | Integration | Ready | ADR-0005 |
| 003 | [Actors are lit only by their key and rim light, never ambient, fill or set light](story-003-actor-key-and-rim-lighting-only.md) | Logic | Ready | ADR-0005 |
| 004 | [SpriteProjection returns an exact, pixel-snapped quad at the foot anchor for any camera and frame size](story-004-sprite-projection-pixel-exact-quad.md) | Logic | Ready | ADR-0005 |
| 005 | [no_mirror animations use authored opposite-facing art instead of the shader flip](story-005-no-mirror-animations-use-authored-art.md) | Logic | Ready | ADR-0005 |
| 006 | [The battle camera only changes through frustum_offset: lens shift plus the hit-punch](story-006-battle-camera-lens-shift-only.md) | Logic | Ready | ADR-0005 |
| 007 | [Camp and Title cameras never move](story-007-camp-and-title-cameras-never-move.md) | Logic | Ready | ADR-0005 |
| 008 | [Every mode entry applies its lighting profile fully before the transition reveals it](story-008-mode-entry-applies-lighting-before-reveal.md) | Integration | Ready | ADR-0005 |
| 009 | [A lighting blend reaches p=1 exactly on its last frame and never pops](story-009-lighting-blend-completes-without-popping.md) | Logic | Ready | ADR-0005 |
| 010 | [Opening the Menu freezes every presentation clock, beat, punch and particle](story-010-menu-freeze-stops-every-presentation-clock.md) | Visual/Feel | Ready | ADR-0005 |
| 011 | [Sprite animation keeps advancing while Dialogue or the Defeat Prompt is open](story-011-dialogue-and-defeat-prompt-keep-animation-running.md) | Logic | Ready | ADR-0005 |
| 012 | [Exactly one hit-punch starts per beat, on that beat's impact frame](story-012-one-hit-punch-per-beat-on-impact.md) | Logic | Ready | ADR-0005 |
| 013 | [A punch requested during a boss-takeover blend or hold is dropped, never deferred](story-013-punch-dropped-during-boss-takeover.md) | Logic | Ready | ADR-0005 |
| 014 | [A hit-punch never changes an actor's world position](story-014-hit-punch-never-moves-actor-position.md) | Logic | Ready | ADR-0005 |
| 015 | [A battle replay plays beats in log order, impacting, holding and ending on the controller's own clocks](story-015-battle-replay-plays-beats-in-order.md) | Integration | Ready | ADR-0006 |
| 016 | [The replay never mutates BattleCore, and the HUD always shows each combatant's live values](story-016-replay-never-mutates-battlecore.md) | Logic | Ready | ADR-0006 |
| 017 | [Each shipped move resolves to its documented pose, reactions, numbers and punch shape](story-017-move-outcome-shapes-match-the-table.md) | Logic | Ready | ADR-0006 |
| 018 | [Missing required animations fail Boot; missing optional ones fall back with one warning](story-018-boot-validation-of-sprite-set-animations.md) | Logic | Ready | ADR-0005 |
| 019 | [The squad's rim and outline colors stay constant, and no non-boss light matches a faction color](story-019-squad-rim-and-outline-stay-constant.md) | Logic | Ready | ADR-0005 |
| 020 | [Only the set light casts shadows; every actor gets exactly one blob shadow](story-020-one-blob-shadow-per-actor-set-light-only-caster.md) | Logic | Ready | ADR-0005 |
| 021 | [Screen Shake and Reduce Motion settings zero or halve the hit-punch offset](story-021-screen-shake-and-reduce-motion-scale-the-punch.md) | Logic | Ready | ADR-0005 |
| 022 | [battle_framing keeps every actor slot in view and the foot row on the formula's curve](story-022-battle-framing-keeps-every-slot-in-view.md) | Logic | Ready | ADR-0005 |
| 023 | [The follow camera's dead zone, tau and ground-footprint clamp match the formula exactly](story-023-follow-camera-matches-the-formula.md) | Logic | Ready | ADR-0005 |
| 024 | [hit_punch's offset formula is pixel-exact and never starts while another punch is running](story-024-hit-punch-formula-is-pixel-exact.md) | Logic | Ready | ADR-0005 |
| 025 | [A hit-punch displaces every near, far and set-element pixel by the same whole-pixel amount](story-025-punch-displaces-the-id-pass-by-whole-pixels.md) | Visual/Feel | Ready | ADR-0005 |
| 026 | [lighting_blend reaches p=0.5 at half its duration and never jumps by more than one frame-step](story-026-lighting-blend-formula-is-exact.md) | Logic | Ready | ADR-0005 |
| 027 | [replay_time holds the formula across every speed, latch and knockout case](story-027-replay-time-holds-every-case.md) | Logic | Ready | ADR-0006 |
| 028 | [set_brightness_and_blur matches the lighting curve in every battle-family state](story-028-set-brightness-and-blur-match-lighting-states.md) | Logic | Ready | ADR-0005 |
| 029 | [FlashGate books every large-area transition at its landing time, not its request](story-029-flash-gate-books-transitions-at-landing-time.md) | Logic | Ready | ADR-0005 |
| 030 | [a Retry or a cancelled first-encounter takeover lands on the right light, never a pop](story-030-retry-and-cancel-in-a-boss-fight.md) | Logic | Ready | ADR-0006 |
| 031 | [the follow camera snaps on a warp and stays clamped inside the map](story-031-camera-snaps-on-warp-and-clamps-at-map-edges.md) | Logic | Ready | ADR-0005 |
| 032 | [an alien faction with no boss lighting preset fails boot, never the fight](story-032-missing-boss-preset-fails-boot.md) | Integration | Ready | ADR-0005 |
| 033 | [the command menu, Defeat Prompt and outcome report open only after the replay, never off BattleCore's raw signals](story-033-command-menu-and-outcomes-wait-for-the-replay.md) | Integration | Ready | ADR-0006 |
| 034 | [an unknown sprite_set_id fails boot; the checkerboard placeholder reaches Title](story-034-unknown-sprite-set-id-fails-boot.md) | Integration | Ready | ADR-0005 |
| 035 | [the battle benchmark holds its frame-time and draw-call budget on both target devices](story-035-battle-performance-budget.md) | Integration | Ready | ADR-0005 |
| 036 | [one capture per lighting state passes read order and shows no glow on actors](story-036-capture-one-screen-per-lighting-state.md) | Visual/Feel | Ready | ADR-0005 |
| 037 | [every character's silhouette passes the 2-of-3 lineup test](story-037-silhouette-sheet-passes-the-lineup-test.md) | Visual/Feel | Ready | ADR-0005 |
| 038 | [every faction's boss takeover is lavish on its own terms, with no faction left behind](story-038-boss-takeover-faction-parity.md) | Visual/Feel | Ready | ADR-0005 |
| 039 | [every sprite's texels are whole, uniform pixel blocks at every shipped resolution](story-039-texel-scale-holds-across-resolutions.md) | Visual/Feel | Ready | ADR-0005 |
| 040 | [a Retry, Retreat or Quit mid-replay discards cleanly and never leaves a stale frame](story-040-retry-and-exit-mid-replay-clear-the-display.md) | Logic | Ready | ADR-0006 |
| 041 | [every boss stage frames its faction's colorblind-safe shape in view](story-041-boss-stage-frames-a-colorblind-shape.md) | Integration | Ready | ADR-0005 |
| 042 | [the replay indicator shows the right state and every press either latches, un-latches or is refused](story-042-replay-indicator-and-latch-input.md) | Logic | Ready | ADR-0006 |
| 043 | [a 0.5-second frame never skips a beat or double-fires its events](story-043-slow-frame-never-skips-a-beat.md) | Logic | Ready | ADR-0006 |
| 044 | [the follow camera holds its position while Dialogue is open](story-044-dialogue-holds-the-follow-camera.md) | Logic | Ready | ADR-0005 |
| 045 | [a comfort-setting change mid-punch applies on the very next frame](story-045-setting-change-mid-punch.md) | Logic | Ready | ADR-0005 |
| 046 | [no two actor slots share a view depth, in every shipped formation](story-046-no-two-actor-slots-share-a-depth.md) | Logic | Ready | ADR-0005 |
| 047 | [every battle stage keeps every actor slot visible above the occlusion threshold](story-047-occlusion-and-visibility-pass-the-threshold.md) | Visual/Feel | Ready | ADR-0005 |
| 048 | [Reduce Motion zeroes the punch and ambient set motion, and swaps in the still confetti](story-048-reduce-motion-zeroes-ambient-motion.md) | Logic | Ready | ADR-0005 |
| 049 | [the boss takeover starts on reveal, runs on one clock, and holds the battle](story-049-boss-takeover-runs-on-one-clock.md) | Integration | Ready | ADR-0006 |
| 050 | [every actor slot stays inside the battle camera's view at every supported aspect ratio](story-050-camera-holds-every-slot-in-view-at-every-aspect.md) | Logic | Ready | ADR-0005 |
| 051 | [Rendering constraints are pinned at the project level](story-051-rendering-constraints.md) | Logic | Ready | ADR-0005 |
| 052 | [No emissive source bleeds through an actor's silhouette](story-052-no-emissive-behind-actor.md) | Visual/Feel | Ready | ADR-0005 |
| 053 | [The Defeat spotlight centres on the party's formation](story-053-defeat-spotlight-formation-centre.md) | Logic | Ready | ADR-0005 |
| 054 | [The follow camera holds still while the Menu is open](story-054-follow-camera-holds-under-the-menu.md) | Logic | Ready | ADR-0005 |
| 055 | [A window resize recomputes the punch and the camera headlessly](story-055-resize-recomputes-punch-and-camera.md) | Logic | Ready | ADR-0005 |
| 056 | [Comfort settings changed mid-replay apply from the next frame](story-056-comfort-settings-change-mid-replay.md) | Logic | Ready | ADR-0006 |
| 057 | [The UI layer is never tinted by the world's tonemapper](story-057-ui-never-tinted-by-the-world.md) | Visual/Feel | Ready | ADR-0005 |
| 058 | [The menu input guard refuses presses for its full window](story-058-menu-input-guard.md) | Logic | Ready | ADR-0008 |
| 059 | [Every flash-capable source is declared and classified](story-059-flash-coverage-declared-for-every-source.md) | Logic | Ready | ADR-0005 |
| 060 | [The flash analyser checks composited frames against flash_rate_max](story-060-composite-frame-flash-analysis.md) | Visual/Feel | Ready | ADR-0005 |
| 061 | [PresentationConfig's load rules are validated at boot](story-061-presentation-config-load-validation.md) | Logic | Ready | ADR-0005 |
| 062 | [A boss sprite set with no front intro fails boot](story-062-boss-intro-animation-required.md) | Logic | Ready | ADR-0005 |
| 063 | [A moving sprite stays pixel-snapped in every mode](story-063-pixel-snap-in-every-mode.md) | Logic | Ready | ADR-0005 |
| 064 | [A stale damage number is cleared before the next one lands](story-064-old-damage-number-cleared.md) | Logic | Ready | ADR-0006 |
| 065 | [Presses before the reveal and at replay start are latched correctly](story-065-presses-before-the-reveal-do-nothing.md) | Logic | Ready | ADR-0006 |
| 066 | [Impact and landing frame data is required at boot](story-066-impact-and-landing-frame-data-required.md) | Logic | Ready | ADR-0005 |
| 067 | [End-of-fight holds complete before the outcome is reported](story-067-end-of-fight-holds.md) | Logic | Ready | ADR-0006 |
| 068 | [Reduce Flashing halves the campfire flicker's swing](story-068-reduce-flashing-halves-campfire-flicker.md) | Logic | Ready | ADR-0005 |
| 069 | [Nothing compiles a rendering pipeline in play, measured](story-069-nothing-compiles-in-play.md) | Integration | Ready | ADR-0005 |
| 070 | [Outcome numbers and the round number release on the right frame](story-070-outcome-numbers-and-round-on-the-hud.md) | Logic | Ready | ADR-0006 |
| 071 | [The anchor moment reads clearly to first-time players](story-071-the-anchor-moment-playtest.md) | Integration | Ready | ADR-0005 |
| 072 | [The squad is never tinted by a faction's boss flood](story-072-squad-never-tinted-by-the-boss-flood.md) | Visual/Feel | Ready | ADR-0005 |
| 073 | [Upright-card occlusion holds under pitched cameras](story-073-upright-card-occlusion-under-pitched-cameras.md) | Visual/Feel | Ready | ADR-0005 |
| 074 | [Retained screenshots of the replay indicator and the refusal pulse](story-074-replay-indicator-and-refusal-pulse-screenshots.md) | UI | Ready | ADR-0006 |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/sprite-camera-presentation.md verified
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
