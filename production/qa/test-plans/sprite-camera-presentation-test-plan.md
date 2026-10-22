# Test Plan: Sprite & Camera Presentation

> **System**: Sprite & Camera Presentation (`design/gdd/sprite-camera-presentation.md`, revision 6)
> **Created**: 2026-10-22, from creative-director ruling 7 of the fifth `/design-review`. The test procedures moved here out of the GDD; the GDD's ACs state observable outcomes and name the procedures below.
> **Mechanism under test**: `docs/architecture/adr-0005-sprite-camera-presentation.md` (revision 2) and `docs/architecture/adr-0006-battle-replay-ownership.md` (revision 3). Their own Validation Criteria cover the build and the controller; this plan covers what the player sees.
> **Status**: Draft. The capture tool (P-09), the flash analyser (P-13) and the benchmark scenes (P-14, P-15) do not exist yet. Each is built by its own story (ADR-0005 Migration Step 1c), and a story that ships a measured feature can't close on a [C] or [P] clause until its tool exists.

## Procedure index

| ID | Procedure | Kind | Used by |
|---|---|---|---|
| P-01 | Headless harness | [L]/[I] setup | AC-8, AC-29, AC-45, every [L]/[I] AC |
| P-02 | Test conventions | rules | every [L]/[I] AC |
| P-03 | Sprite projection suite | [L] | AC-2, AC-51, AC-58, AC-68 |
| P-04 | Replay suite | [L]/[I] | AC-10–14b, AC-18, AC-21, AC-23, AC-26, AC-29, AC-36, AC-39, AC-41, AC-45, AC-52, AC-59, AC-62, AC-65 |
| P-05 | Input and flash-gate suite | [L] | AC-25, AC-38, AC-54, AC-55, AC-60, AC-62 |
| P-06 | Lighting, data and validation suite | [L]/[I] | AC-1, AC-3, AC-6, AC-7, AC-9, AC-15–17, AC-22, AC-24, AC-28, AC-30, AC-44, AC-47, AC-49, AC-56, AC-57, AC-61, AC-63 |
| P-07 | Camera and stage suite | [L]/[I] | AC-4, AC-5, AC-19, AC-20, AC-27, AC-37, AC-40, AC-42, AC-43, AC-46, AC-50, AC-51 |
| P-08 | Live Menu-freeze capture | [C] | AC-8 |
| P-09 | Capture tool | [C] tool | AC-21b, AC-32, AC-34, AC-35, AC-48, AC-53, AC-67 |
| P-10 | Read-order measurement | [C] | AC-32, AC-48 |
| P-11 | Flood measurement | [C] | AC-34 |
| P-12 | Texel measurement | [C] | AC-35 |
| P-13 | Flash analyser and composite sequences | [C] tool | AC-55b |
| P-14 | Battle benchmark | [P] | AC-31 |
| P-15 | Pipeline-compilation benchmark | [P] | AC-64 |
| P-16 | Anchor-moment playtest | [PT] | AC-66 |
| P-17 | Art-director sign-off sheets | [VF] | AC-32–35, AC-43 |
| P-18 | UI screenshot set | [UI] | AC-69 |

## P-01 Headless harness

All [L] and [I] tests drive the presentation stage through injected services and stubs, never real time or real input:
- **Game State:** a stub that emits mode, transition and overlay announcements in ADR-0002's order, including the Battle → Battle row for Retry.
- **Battle:** either a real `BattleCore` with a **seeded RNG**, or a stub signal source that emits `action_resolved`, `round_advanced`, `turn_started` and `battle_ended` in a scripted order. Either one feeds a real `BattleReplayController`. A spy records any call to a `BattleCore` mutator.
- **Content:** a stub catalog.
- **Clocks:** an injectable **mode-time** clock, stopped while the Menu is open, so the replay is driven through `advance(dt)` with chosen steps. A separate injectable **real-time** clock in integer microseconds, for the flash gate.
- **Logger:** an injectable logger, so warnings and errors can be counted.
- **Settings:** injectable values for Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur, Reduce Flashing and Reduce Motion.
- **Input:** a stub source that emits `pressed`/`released` per frame, navigation repeats, injected OS key-repeat echoes, and pointer motion and clicks.
- **Viewport:** an injectable viewport size, so resize and aspect tests run headless.
- **Globals:** the `GlobalUniformSink` of ADR-0005. Tests read the values the Director wrote through the sink. `RenderingServer.global_shader_parameter_get()` returns null at runtime on 4.7.2 (observed), so tests never read the globals back from the engine.
- **Probe:** reads lighting parameters, the camera's transform, field of view and lens shift, each `CharacterSprite`'s animation, frame and shader inputs, particle processing state, and the sink's `mode_time`.

## P-02 Test conventions

- **Expected values** are calculated from the presentation data through the GDD's Formulas, never written as literals. Each formula test also runs once with a non-default config.
- **Determinism:** the battle RNG is seeded, and no test reads wall-clock time.
- **Tolerances:** lighting values and metres 1e-4; pixel offsets exact; times within one frame step of the test's fixed `dt` (1/60 s) **per event**. A span covering N events (beats, impacts, holds) allows N steps, because the replay clock drops leftover `dt` at every event (ADR-0006).
- **No assertion on a threshold frame:** wherever a test checks behaviour on either side of a time threshold, the config puts the threshold half a frame from any frame boundary (for example `input_guard = 9.5 / 60` s, a 26.5-frame blend, `D = 0.105` s). The test asserts the frames on each side of it.
- **Ties are tested on the pure function:** a rounding tie (such as the hit-punch's 0.5 px) is checked by calling the formula's function with exact inputs, never by sampling frames.
- **Test resolution:** unless stated, [C] and [VF] captures render at 1920×1080. Values given "in texels" scale with `T`, and values "at 1080p" scale with height.

## P-03 Sprite projection suite

- The pure projection function (ADR-0005) is called with fixture anchors, cameras (the level battle camera with a lens shift; a pitched Overworld camera), frame sizes and viewport heights. Its quad size, bottom-centre rounding and `T` are compared with `texel_scale`.
- Each `CharacterSprite`'s shader inputs are read from its material every frame and compared with the function's output.
- **Upright-card depth (AC-68):** the depth function is called along fixture view rays through a sprite in front of a fixture wall, and compared with the analytic intersection of each ray with the upright card at the foot anchor.

## P-04 Replay suite

- Replays are built from a seeded `BattleCore` or a scripted stub, and played with `advance(1/60)` under every speed case of the GDD's `replay_time`.
- Observations come from the controller's signals and queries, from the probe's sprite and punch readings, and from the HUD's displayed values. Expected times come from `replay_time`.
- Retry and exit cases use the stub Game State's Battle → Battle row and `transition_started` away from Battle, with a spy on the Battle mode recording the call order.

## P-05 Input and flash-gate suite

- **Input:** menus and the replay indicator are driven by the stub input source, on the mode-time clock. Refusal events are counted from the UI Framework's refusal signal.
- **Flash gate:** the gate is driven by the real-time clock in microseconds, with fixture sources whose transitions are declared as offsets. The WCAG classifier is tested on fixture frame pairs of known luminance, red content and area.

## P-06 Lighting, data and validation suite

Shipped and fixture lighting presets, sprite sets and presentation configs are loaded through the real validators. Boot-validation failures are asserted as content errors naming the rule, set or animation.

## P-07 Camera and stage suite

Battle stages are loaded and validated against `battle_framing`, and the overworld camera against `follow_camera`, at 16:9, 21:9, 16:10 and 4:3 through the injected viewport size. Ground hits of the view's corner rays are computed analytically from the camera.

## P-08 Live Menu-freeze capture

- **Run:** a windowed run of the game (not the capture tool, whose mode time is fixed).
- **Setup:** a Battle stage with a moving-particle fixture, played to case (a) of AC-8.
- **Grabs:** two grabs of the main viewport's texture, taken 1 s of real time apart, with the Menu open.
- **Control:** the same two grabs with the Menu closed.

It passes if the Menu-open pair is identical in the world layer and the Menu-closed pair differs. The control proves the check can fail.

## P-09 Capture tool

`tools/capture/presentation_capture.gd`, built in ADR-0005 Migration Step 1c with its own story. It does the following.

**Input.** It loads a named stage and lighting state, with mode time fixed and an injected battle state.

**Render.** It renders into an offscreen `SubViewport` of the stated size, so a 4K check needs no 4K monitor. A `SubViewport` does **not** inherit the project's MSAA, screen-space AA or shadow atlas settings (observed on 4.7.2: a 2048 vs 4096 positional shadow atlas), so the tool sets each of them explicitly from the project settings and records them in its output.

**Passes.** Besides the normal frame, it renders:
- **an ID pass** of the same frame, labelling every pixel as one of:
  - actor (with its slot);
  - Outline Ink;
  - rim band;
  - costume band;
  - sky;
  - emissive set;
  - faction shape;
  - other set;
  - UI;
  - clear (a sentinel no shipped material uses).

  Every pixel-class test selects pixels from this pass, never by color;
- **a set-light shadow mask** (lit vs shadowed set pixels), for AC-34's contrast clause;
- **an unlit-albedo mode** (lighting, DOF, glow and tonemapping off, anti-aliasing off), for AC-35;
- **the UI layer alone**, into a transparent viewport, for AC-53;
- **the engine's glow input**, before tonemapping, for AC-32's glow clause. This needs a compositor hook (ADR-0005 Verification Required).

**Output.** It writes the PNGs, the ID pass and a measurements file to `production/qa/evidence/`.

It needs a GPU and a windowed run (Godot's headless mode renders nothing), so [C] clauses run on the development PC, not in headless CI.

## P-10 Read-order measurement

For each actor in the ID pass:
1. **Bands.** Take the rim band (1 texel inside the Outline Ink outline), the costume band (`body_tx` texels further in) and the ring (`ring_tx` texels outside the outline).
2. **Exclusions.** Drop ring pixels below the foot anchor's row, and emissive pixels.
3. **Sectors.** Split the edge band and the ring into 8 sectors around the quad's centre.
4. **Contrast.** Compute WCAG relative luminance per pixel, and `C_s` per sector.
5. **Report.** Report each sector as pass, fail, skipped (fewer than `band_px_min` pixels) or failed-for-emissive (less than half its ring remains). A capture with fewer than 6 valid sectors for any actor is invalid.
6. **Boss takeovers.** Also compute the costume band's and ring's mean CIELAB and their ΔE2000.

## P-11 Flood measurement

1. **Sky pixels.** Take the ID pass's sky pixels, shrunk by 2 px at the sky's edges.
2. **Match.** Convert to CIELAB LCh (D65), and count the pixels within `flood_hue_tol` and `flood_chroma_tol` of the swatch.
3. **Lightness.** Check every pixel's L\* against the swatch range widened by `flood_l_gradient`, and the L\* standard deviation.
4. **Share.** Compute `sky_share` over the whole frame.
5. **Native sky.** Compute ΔE2000 between the swatch midpoint and the mean sky color of the same stage's Battle capture.

## P-12 Texel measurement

1. **Render.** Render the unlit-albedo mode at each stated size.
2. **Grid.** For every sprite in the ID pass, derive its expected texel grid from the projection function, as `T × T` blocks anchored at the quad's bottom-centre.
3. **Blocks.** Assert that each block is a single color. Assert that the block size equals `T` for near and far rows alike.
4. **Lit spread.** In the lit mode, report each block's internal ΔE2000 spread.

## P-13 Flash analyser and composite sequences

**The analyser** is a frame-sequence analyser, built with its own story.
- **Input:** it reads the final composited frames, world and UI together, captured at 60 fps from a windowed run, never from the capture tool's fixed-time renders.
- **Classification:** it classifies general and red transitions with the GDD's `flash_gate` definitions: linear R, G, B, a 10° window of `(4/9)·H × (1/3)·H`, and 25% area.
- **Counting:** it counts flashes per sliding one-second window with the gate's conservative N − 1 rule.

**Scripted sequences**, each run with Reduce Flashing Off and On:
1. Battle entry with the wipe, then a boss takeover.
2. A replay with hit sparks and the faction stamp, latched.
3. Victory with confetti, into the results screen.
4. Defeat, the Defeat card's stamp, then Retry with the retry flash.
5. The Menu opened and closed during a replay.

## P-14 Battle benchmark

**Setup.** On the development PC, in a windowed release export (not headless, not the editor), the benchmark scene runs a battle with 8 actors. A debug driver restarts the boss takeover every 2.0 s of mode time, so every measured window contains blends and holds.

**Runs.** 5 runs at 1920×1080, each of 600 measured frames after 120 warm-up frames, with vsync off.

**Recorded per frame:** CPU and GPU frame times separately, and the larger of the two as the frame time. Also the engine's total draw calls per frame (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`).

**Information only, not a gate:** DOF and glow are each measured on and off, and recorded for the technical-director.

**Pending (GDD Open Question 13):** the draw-call budget and counting rule, the 99th-percentile and worst-frame limits, and the target hardware.

## P-15 Pipeline-compilation benchmark

**Setup.** A freshly launched windowed release export with an empty shader cache. It runs Boot, including the warm-up, then the scripted state cycle:
- each mode's entry;
- Battle, every faction's boss takeover, Victory and Defeat;
- Camp;
- the Menu opened and closed.

**Recorded.** Every `Performance.PIPELINE_COMPILATIONS_*` counter (canvas, mesh, surface, draw, specialization; present on 4.7.2) is recorded after the warm-up and after the cycle, along with the worst frame time.

**Negative control.** A fixture preset that switches an un-warmed feature must raise a counter.

## P-16 Anchor-moment playtest

- **Players:** five first-time players who haven't seen the game.
- **Session:** each plays from the title into their first battle and their first boss fight, with no explanation.
- **Recording:** an observer times the first battle wipe's opening and records each player's answers and visible reactions, against AC-66's three questions.
- **Location:** records go in `production/qa/playtests/`.
- **Gate:** it gates the first-playable milestone. A missed threshold blocks that gate until a design revision passes a rerun with five new players.

## P-17 Art-director sign-off sheets

Each [VF] clause gets a retained capture set in `production/qa/evidence/`, plus a signed evidence doc (`[story-slug]-evidence.md`) recording:
- the art director's verdict per clause;
- the capture files' hashes;
- the build they came from.

AC-34's side-by-side review shows all faction takeovers on one sheet.

## P-18 UI screenshot set

Retained screenshots at 1080p, with keyboard and gamepad glyphs, over Battle and each faction's boss takeover:
- the replay indicator in its three states;
- the refusal pulse on the command menu.
