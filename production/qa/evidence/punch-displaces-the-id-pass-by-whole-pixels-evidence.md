# Evidence: Story 025, a hit-punch displaces every near, far and set-element pixel by the same whole-pixel amount

Story: `production/epics/sprite-camera-presentation/story-025-punch-displaces-the-id-pass-by-whole-pixels.md`
AC: GDD `design/gdd/sprite-camera-presentation.md` AC-21b [C]. Date: 2026-10-31. Engine 4.7.2, Vulkan, RTX 4080 SUPER, windowed 1280x720 (`H_screen` = 720).

## Method

The tool is `tools/capture/punch_shift_capture.gd`, which is windowed and renders in the main viewport.
- It boots the real `BattleMode` on `enc_paris_clerks_hall`, settles it, and then freezes it.
- For each state it sets the stage's punch to `HitPunch.offset_px(0, D, A_peak, dir)`; `t = 0` is the punch's peak.
- It then runs one presentation frame (`BattleView.present()`), so every sprite re-projects exactly as it does in play.
- It renders the ID pass through `PresentationCapture.apply_id_overrides()`. Actor cards keep their projection, the environment is flat, and the UI is hidden.
- `PunchShiftCheck.best_shift()` searches every whole-pixel shift within `A_peak + 2` and finds the one that maps each region's class mask in the no-punch frame (`id_none.png`) exactly onto the peak frame.
- Regions:
  - each near actor (the squad, 4 regions);
  - the far actor (the Clerk);
  - the set class, which is the blob shadows (the battle stage's 3D set geometry).
- Each region is clipped by the search radius from the frame edge.
- The maths is unit-tested headless in `tests/unit/presentation/punch_shift_check_test.gd` (5/5). Against a stub it failed first. One test is a stretched shape that no single shift can match, which is how a translation shake would show up.

## Result: PASS (`punch-displaces-the-id-pass-by-whole-pixels/measurements.json`)

| Case | `A_peak` | Punch (px, y down) | Every region's measured shift | Mismatched pixels | Runner-up mismatch |
|---|---|---|---|---|---|
| big, up (`punch_amplitude_big` 7.0) | 5 | (0, -5) | (0, -5) | 0 in all 6 regions | 204 to 360 |
| big, down | 5 | (0, 5) | (0, 5) | 0 in all 6 regions | > 0 in all |
| normal, up (`punch_amplitude_normal` 3.0) | 2 | (0, -2) | (0, -2) | 0 in all 6 regions | > 0 in all |

Each near actor, the far actor and the set element moved by the same whole number of pixels, `A_peak` in the punch direction, with no pixel left over. A runner-up mismatch above 0 means the best shift was unambiguous.

Images (I opened `id_big_up.png` myself and saw the five actor silhouettes and five blob quads in distinct ID colours):
- `id_none.png`
- `id_big_up.png`, `id_big_down.png`, `id_normal_up.png`
- `final_*.png`: the lit frames at each peak

Stamp: `punch-displaces-the-id-pass-by-whole-pixels/stamp.txt`.

## Notes and limits

- The battle backdrop is a 2D `CanvasLayer`, not 3D set geometry, so it is not in the ID pass. It follows the punch through `BattleView._follow_punch()` (`layer.offset = punch_offset_px`), which is the same whole-pixel offset by construction, but this capture does not measure it.
- Blob shadows draw as full quads in the ID pass. The generic ID override does not use their alpha texture, but their footprint still moves with the camera.
- Only one window height (720) was captured. At 1080, `A_peak` is 7 for a big punch; the measurement does not depend on height.
- `apply_id_overrides()` depends on the actor-card ID variant in `tools/capture/presentation_capture.gd`, which another agent was still editing at capture time (story 072). It was not committed then.

## Sign-off

Lead sign-off: owed.
