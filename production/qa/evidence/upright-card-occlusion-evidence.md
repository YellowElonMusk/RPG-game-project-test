# Story 073 evidence: upright-card occlusion holds under pitched cameras

**AC-68 [L]+[C]** (GDD `sprite-camera-presentation.md`, Acceptance Criteria; ADR-0005 §2 as amended 2026-10-31, §13)
**Date**: 2026-10-31 | **Build**: branch `slimed-down-fork`, Godot 4.7.2, Vulkan Forward+, RTX 4080 SUPER, windowed

## [L]: PASS

`tests/unit/presentation/card_depth_test.gd` (3 cases) tests `SpriteProjection.sprite_card_depth()`. That is the
sprite-level card-depth function: the ray through a window pixel meets the upright card through
`card_plane_point()` (the ground point under the rounded bottom edge) with normal `card_normal()`. It is checked
against an analytic value built independently (pinhole ray from `tan(fov/2)` and aspect, not the projection
matrix; plane point and ground-projected normal rebuilt from the transform). It is checked at every pixel centre
of the rect plus its 4 corners, for 3 anchors per camera and 3 pitched cameras (shipped Overworld h 12 / pitch 30 /
fov 20 at 16:9 and 4:3; a yawed 45° camera standing in for Camp). That is more than 10 000 rays, all within 1e-4 m.
A case with the fixture wall 0.5 m behind checks that every ray meets the card at least 0.25 m before the wall.

- Seen failing first: against a stub returning 0.0 (`card depth 0.000000, analytic 23.751195`).
- Negative control: the function was temporarily switched to the pre-039 rule (plane through the foot anchor),
  and the test then failed (`card depth 23.756554, analytic 23.751195`: 5.4 mm, 54× the tolerance). Restored.

## [C] Overworld: PASS

Run: `godot --path . -s res://tools/capture/card_occlusion_capture.gd`. Exit 0, `result: PASS`.

- Real `OverworldMode`, `map_paris_town_placeholder`, at 1920×1080 (T = 3) with the shipped follow camera (pitch
  30°), MSAA 2× as in the project settings. Only the party leader is shown (followers, symbols and UI hidden).
- Leader rect `[942, 330, 36, 72]` (12×24 texels), equal to `SpriteProjection.screen_rect()` from the live camera.
  The foot anchor is `(12.5, 0, 8.5)` and the card plane point is `(12.5, 0, 8.5047)`, so the 039 rule moved the
  card 4.7 mm.
- Fixture, built from `SpriteProjection`: a 3×3 m wall (flat ID red) with its front face 0.5 m behind the card,
  and a 2 m wide prop (flat ID orange) 5 cm in front of the card, 0.093 m tall. That height puts its top edge on
  screen 1 cm of height above the bottom-2-texel band.
- All passes come from one frozen frame: the ID pass of the leader alone, with the fixture, and the fixture with
  the leader hidden. `tools/capture/card_occlusion_check.gd` (`CardOcclusionCheck.verdict`) judged them:

| Case | Upper-half px | wall behind | missing | Band px (bottom 2 texels) | prop in front | present | Verdict |
|---|---|---|---|---|---|---|---|
| Shipped card | 864 | 864 | **0** | 216 | 216 | **0** | PASS |
| Control: card plane +0.7 m (behind the wall) | 864 | 864 | 864 | 216 | 216 | 0 | FAIL (expected) |
| Control: card plane −0.3 m (in front of the prop) | 864 | 864 | 0 | 216 | 216 | 216 | FAIL (expected) |

The controls use the shipped `sprite_actor.gdshader` with one line added after `_card_plane_point()`: the plane
moved along the card normal. The capture fails unless both controls fail. The check itself is unit-tested headless
against synthetic passes: `tests/unit/presentation/card_occlusion_check_test.gd` (6 cases), seen failing against
a stub first. It covers pass, both occlusion failures, a prop short of the band, no wall behind, and an empty
sprite. The last three are invalid or vacuous fixtures, and each one fails.

## [C] Camp: BLOCKED (content)

Camp has no 3D scene, `DioramaStage` or camera yet, so there is nothing to capture. The AC's [C] clause names
only an Overworld capture, but the story's notes ask for Camp separately. The [L] half covers a representative
fixed, yawed, pitched camera. When a Camp stage ships, add it to `card_occlusion_capture.gd` (same fixture,
same check).

## Retained images (opened and checked)

- `upright-card-occlusion/overworld_fixture_lit.png`: the town at the spawn. The leader placeholder stands
  between the red wall and the orange prop, with its feet hidden behind the prop and its body whole against the wall.
- `overworld_fixture_id_crop.png` (4× nearest): navy actor whole over the red wall. Its bottom rows are hidden
  under the orange prop, with floor-blue between the wall's base and the prop.
- `overworld_control_card_behind_wall_id_crop.png`: no actor pixel at all (wall red, floor blue, prop orange).
- `overworld_control_card_in_front_of_prop_id_crop.png`: the actor's feet drawn over the prop.
- Full frames `overworld_{alone,fixture,behind,control_*}_id.png`, plus `measurements.json`.

## Sign-off

- [ ] Art director / lead: the occlusion reads correctly (body never cut by set behind, feet hidden by set in
  front). **PENDING**: human sign-off is not given by the implementing agent.
