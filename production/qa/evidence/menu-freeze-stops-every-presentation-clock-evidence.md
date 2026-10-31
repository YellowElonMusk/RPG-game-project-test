# Evidence: Story 010, opening the Menu freezes every presentation clock, beat, punch and particle

Story: `production/epics/sprite-camera-presentation/story-010-menu-freeze-stops-every-presentation-clock.md`
AC: GDD `design/gdd/sprite-camera-presentation.md` AC-8 [I]+[C]. Date: 2026-10-31. Engine 4.7.2, Vulkan, RTX 4080 SUPER, windowed 1280x720.

## [I]: `tests/integration/presentation/menu_freeze_test.gd` (5/5)

This test uses a real Battle mode under a stand-in `ModeHost`, which the stub loader disables the same way `ModeHostSceneLoader` does. Real engine frames run, and a `PresentationDirector` writes to a recording sink.
- Cases (a) mid-wind-up, (b) the punch's third frame and (c) mid-blend of the first-encounter takeover each run 300 frames with the Menu open. These values stay unchanged: the sink's `mode_time`, the rim globals, every lighting value and light, the blend `p`, the lens shift (`frustum_offset`), the punch offset and its clock, every sprite's animation and frame, and the replay's state, clocks, latch and round. No replay event fires during those frames.
- Every particle node in the mode scene reports `can_process() == false`. This includes a fixture deliberately set to `PROCESS_MODE_ALWAYS`, which the stage's explicit pause catches. On close, each particle's previous mode is restored.
- On the frame after the Menu closes:
  - `mode_time`, the replay clocks and the punch clock each move by more than 0 and at most `dt_max`.
  - The takeover blend's `p` moves by at most `1.5 * dt_max / blend_boss`.
  - Each sprite moves by at most one frame.
- Dialogue and the Defeat Prompt do not pause ambience (story 011's boundary).
- No shipped mode scene has a node set to always process.
- Control run: with the ModeHost disable removed, the test fails (`'replay' moved on frozen frame 0`).

## [C]: `tools/capture/menu_freeze_capture.gd`, live, with a control

Case (a) uses `enc_paris_clerks_hall`, a squad Attack mid-wind-up (`windup_progress` 0.01), and a moving GPU-particle fixture on the set layer. The "Menu open" state applies the Menu's two effects: the loader's ModeHost disable and the Director's `set_ambient_paused(true)`. The Menu panel itself is UI outside ModeHost and is not drawn, so the whole frame is the world layer.

| Pair (1 s real time apart) | Differing pixels (tolerance 0) |
|---|---|
| Menu open: `open_a.png` / `open_b.png` | **0** (`open_diff.png`) |
| Menu closed, control: `closed_a.png` / `closed_b.png` | 66,921 (7.3%) (`closed_diff.png`: particles, the attacker's swing, the -11 number, HUD bar) |

The wind-up clock read 0.01 before and after the 1 s with the Menu open. Result: PASS (`measurements.json`). I opened the PNGs myself: `open_a.png` shows the battle scene with the particle column beside the Clerk, and `closed_diff.png` shows the expected moving regions.

Gap: this capture applies the Menu's two effects directly instead of going through `GameStateMachine.open_overlay(MENU)` in a full GameRoot boot. The [I] suite covers the machine and Director path.

Stamp: `menu-freeze-stops-every-presentation-clock/stamp.txt`.

## Sign-off

Lead sign-off: owed.
