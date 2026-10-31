# Story 039 evidence: every sprite's texels are whole, uniform pixel blocks at every shipped resolution

**AC-35 [C]+[VF]** (GDD `sprite-camera-presentation.md`, Formulas `texel_scale`; ADR-0005 §2, §6, §13)
**Date**: 2026-10-31 | **Build**: branch `slimed-down-fork`, Godot 4.7.2, Vulkan, windowed
**Sprite path that shipped**: the ADR-0005 §2 **clip-space card** (`sprite_actor.gdshader`), read from every
actor's material by the capture (`measurements.json` → `sprite_path`). The §2 fallback billboard is not in use.

## How it was measured

- `tools/capture/texel_grid_check.gd` (`TexelGridCheck`): the pure measurement. For one sprite it walks every
  frame texel on the grid its `sprite_rect` defines and counts blocks that are split (not wholly this sprite),
  bleeding (transparent texel with sprite pixels), outside the frame, stray pixels, non-uniform blocks,
  inconsistent blocks (one source colour rendered two ways, i.e. a texel sampled off-grid), the largest ΔE inside
  a block, and the **measured** block size (pixel bounding box ÷ the frame's opaque bounds). A colour pass that
  draws a many-coloured sprite in one flat colour fails as vacuous.
- `tools/capture/texel_scale_capture.gd`: boots the real `BattleMode` / `OverworldMode` inside the capture tool's
  `SubViewport` (`PresentationCapture.setup()`), so each sprite reads `get_viewport().size` exactly as in play.
  Each sprite is rendered **alone** (others hidden, UI hidden) in the ID pass, the unlit-albedo pass and the lit
  frame.
- Headless: `tests/integration/presentation/texel_scale_capture_test.gd` (12 cases). It covers the check against
  synthetic renders, plus every shipped sprite set's idle frame drawn with the actor shader's own fragment rule at
  all five AC resolutions, with `T` from the shipped config.

Run: `godot --path . -s res://tools/capture/texel_scale_capture.gd`. **Re-run 2026-10-31 after both Overworld
fixes (below): exit 0, `result: PASS`**: whole-pixel PASS at all 5 sizes, coverage PASS for Battle and
Overworld at all 3 aspects, Overworld set-cut observation empty. The first run's Overworld findings are kept
below as history.

## [C] Whole-pixel texels: PASS

Battle scenes: `bureaucratia` (4 squad + Clerk, Middle Manager, Supervisor, Clerk) and `megacorp_boss`
(4 squad + Security Drone, CEO, Security Drone). That is all 9 shipped sprite sets, near row (squad, `back`) and
far row (enemies, `front`).

| Size | T | Sprites | Measured block, near and far | Split / bleed / stray / outside | Unlit non-uniform / inconsistent | Unlit colours = source colours | Lit max ΔE spread |
|---|---|---|---|---|---|---|---|
| 1280×720 | 2 | 15 | 2×2 all | 0 | 0 / 0 | yes, every sprite (13–23 each) | 0.87 |
| 1600×900 | 2 | 15 | 2×2 all | 0 | 0 / 0 | yes | 0.98 |
| 1920×1080 | 3 | 15 | 3×3 all | 0 | 0 / 0 | yes | 0.87 |
| 2560×1440 | 4 | 15 | 4×4 all | 0 | 0 / 0 | yes | 0.87 |
| 3840×2160 | 6 | 15 | 6×6 all | 0 | 0 / 0 | yes | 0.87 |

Lit spread limit 3.0: met everywhere. Per-sprite rows are in `measurements.json` → `battle.<scene>.whole_pixel`.

**Unlit-albedo mode: deviation, called out.** On 4.7.2, `Viewport.DEBUG_DRAW_UNSHADED` (the story-002 capture
tool's `unlit_albedo` pass) draws the actor card shader **pure black** (first run: every actor pixel `#000000`).
That first run "passed" vacuously. A guard test now catches it
(`test_a_flat_colour_pass_of_a_many_coloured_sprite_is_vacuous_and_fails`). The capture now renders actors with
the card shader's unlit variant instead (same `vertex()` projection and alpha cut, `render_mode unshaded`, emission
zeroed) under the capture tool's flat linear environment. **Follow-up for story 002's owner:** the
`unlit_albedo.png` that `PresentationCapture.capture()` writes shows actors black.

## [C] Coverage: PASS (Overworld fixed 2026-10-31)

| Scene | 16:9 1920×1080 | 21:9 2560×1080 | 4:3 1440×1080 |
|---|---|---|---|
| Battle `bureaucratia`: clear-class px / actors outside | 0 / 0 | 0 / 0 | 0 / 0 |
| Battle `megacorp_boss` | 0 / 0 | 0 / 0 | 0 / 0 |
| Overworld `map_paris_town_placeholder` (party of 4), first run | **261 120** / 0 | **358 136** / 0 | **632 160** / 0 |
| Overworld, after the floor fix | 0 / 0 | 0 / 0 | 0 / 0 |

**Fix (2026-10-31).** `OverworldMap.build_set(grid, presentation)` now sizes the floor with `fit_floor()`. That
is the walk grid grown by `FollowCamera.map_overflow()` plus one cell of slack per side. `map_overflow()` derives
how far the follow camera can see past each map edge from the camera config (`follow_camera_height`,
`_pitch_degrees`, `_fov_degrees`), so it is not a fixed number. On an axis the footprint does not fit, the
clamp centres the focus, and the view then overhangs both edges by `(span − map extent) / 2`. That is evaluated
at 4:3 and at `MAX_SUPPORTED_ASPECT` = 43:18 (3440×1440), which bound the whole supported range. The town
(24×16 m) is shorter than the camera's 18.7 m depth span at 16:9 (27.1 m at 4:3), so it overhangs at every
aspect. The boss chamber (14×14 m) overhangs too. `OverworldMode.presentation`'s setter refits the floor when the
view assigns its own camera config. The follow camera's clamp (stories 031/044) was correct and is unchanged.
Regression test: `tests/unit/overworld/overworld_map_floor_coverage_test.gd`, covering all 4 shipped maps × 4
aspects × spawn, corners, centre and every EntryPoint, plus a taller/wider camera config. It was seen failing
against the old builder first (town, 4:3: a 24×16 floor against a footprint from y −5.5 to 21.5).
The extension uses the map's own `floor_color`, so open ground continues past the outer walls. Whether that
apron should read differently (darker, dressed) is for the art director.

First-run analysis (history):

- Battle's sky is the backdrop canvas layer (`background_mode = BG_CANVAS`, layer −1), not a 3D sky card. For its
  ID pass the capture draws the backdrop flat in the `SKY` class colour, so a hole in the backdrop would still show
  as clear. ID passes: `battle_*_{1920x1080,2560x1080,1440x1080}_id.png` (green = SKY, navy = actors, blue = blob
  shadows).
- **Overworld FAIL.** At the town spawn the follow camera's frame shows the bottom ~22% (more at 4:3, where the FOV
  widens) **past the south edge of the placeholder floor**. `OverworldMap.build_set()` sizes the floor to the walk
  grid's extent only, so the `Environment` background colour shows through (`overworld_*_lit.png` blue band,
  `overworld_*_id.png` black band). Every party actor is inside the frame at all three aspects.
  The fix is set content (owner: overworld / level design), not this story's sprite code. Either extend the set
  (floor and outer walls) beyond the walk grid by at least the camera footprint, or add the ADR-0005 §3 sky/ground
  card to the Overworld stage. I did not change the map builder.

## Feet cut 1 px into the Overworld floor: FIXED 2026-10-31

**After the fix**, `set_cut_observation` is empty (`{}`) at 1920×1080, 2560×1080 and 1440×1080, with the
same anchors that cut before (leader y 401.744 → 402, follower 2 309.671 → 310). The card plane now passes
through the ground point under the **rounded** bottom edge: `SpriteProjection.card_plane_point()`, mirrored in
`sprite_actor.gdshader`'s `_card_plane_point()`. ADR-0005 §2 has been amended, and story 073's AC-68 [L] wording
follows. In battle the plane moves at most ½ px of ground: ≤ 0.012 m on the near row and ≤ 0.025 m on the far
row at 720p. Same-row actors never overlap on screen, so draw order is unaffected, and the battle captures
still PASS. Regression test: `tests/unit/presentation/sprite_projection_card_plane_test.gd`. Every 2× MSAA
sample of the bottom row must sit in front of the floor, under the shipped Overworld camera and the level
battle camera, for anchors that round up by ¼–½ px. It was seen failing with the old rule (card 1–4 mm behind
the floor on the lower sample).

First-run observation (history):

Measured (`measurements.json` → `overworld.set_cut_observation`). At 1920×1080 and 2560×1080 the leader and
follower 2 each have their whole bottom texel row (12 texels) partly covered by the floor: the bottom pixel row is
a 50/50 MSAA blend of sprite and floor. The cause is exact. These two sprites' foot anchors round **up** by more
than ¼ px (true y 401.744 → 402, 309.671 → 310). Under the project's 2× MSAA, depth is tested per sample, and the
lower sample of the bottom pixel row (+0.25 px) then lies below the foot line, where the floor is nearer than the
upright card. Anchors that round down (354.369 → 354), and every anchor at 4:3, are clean. It shimmers as a sprite
walks. Battle has no 3D floor under the actors, so it is unaffected.
Proposed fix (not applied: it changes the card-depth contract that story 073 and `SpriteProjection.card_depth()`
test): in `sprite_actor.gdshader`'s `vertex()`, pass the card plane through the ground point under the
**rounded** bottom edge (the ray through `(x_a, y_a)` meets `y = foot_anchor.y`) instead of through
`foot_anchor`, and mirror that in `SpriteProjection.card_depth()`. This moves depth by at most ½ px of ground, and
no sample above the bottom edge can fall under the floor.

## Retained screenshots (opened and checked)

- `battle_bureaucratia_1920x1080_lit.png`: the full Bureaucratia fight, UI hidden. All 8 actors crisp, near row
  and far row drawn at the same texel size; the far row reads as far by its place in the frame.
- `battle_megacorp_boss_1280x720_unlit.png`: unlit-albedo frame. Every actor shows its palette colours flat on
  black, with no blur.
- `battle_bureaucratia_3840x2160_crop_far_Enemy5_unlit.png`: the far Clerk at T = 6. Clean 6×6 blocks, hard
  edges, no blended texel.
- `battle_bureaucratia_1280x720_crop_near_Squad0_lit.png`: the near Baguette Thrower, lit, at T = 2.
- `battle_megacorp_boss_2560x1080_id.png`: the 21:9 ID pass, all green SKY (backdrop) with every actor inside.
- `overworld_1920x1080_lit.png` / `_id.png`: first run, the coverage failure (blue / black band at the bottom).
  **Re-captured 2026-10-31 after the fix and opened.** The town frame now shows floor below the south wall
  where the blue band was. `overworld_1440x1080_id.png` (previously black bands top and bottom) is now
  entirely set/actor/patch classes. In `overworld_2560x1080_lit.png` the floor continues past the west/east
  walls and below the south wall, with no clear colour anywhere. The party column stands crisp at the town spawn.
- One `_crop_near_*` and one `_crop_far_*` (unlit and lit) per size per battle scene; `_lit` / `_unlit` full
  frames per size.

## Sign-off

- [ ] Art director: texels look crisp at every size; sprites don't read as leaning against or cutting into the
  set (note the Overworld feet observation above); the constant-size rows read as near and far. **PENDING**:
  P-17 human judgement, not given by the implementing agent.
