## The level shift-lens battle camera's math and the `battle_framing` load
## validation (GDD Formulas `battle_framing`, ADR-0005 §6; stories 006, 022,
## 046, 050). Pure and static: every call is a function of a `BattleStage`,
## a `PresentationConfig` and a viewport size, so it runs headless at load
## with no camera or scene. `DioramaStage` applies the same formulas to its
## live `Camera3D`.
class_name BattleFraming
extends RefCounted

## The supported window shapes every stage is checked at (GDD `battle_framing`:
## "at every supported window shape"): 16:9, 21:9, 16:10 and 4:3, all 1080
## rows high. A spec list, not a tuning knob.
const SUPPORTED_VIEWPORTS: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(1728, 1080), Vector2i(1440, 1080),
]
## The default battle camera's window (16:9) -- `visible_share` is measured
## there (GDD rule 4: "at the default battle camera").
const DEFAULT_VIEWPORT := Vector2i(1920, 1080)
## Tolerance every comparison allows in its passing direction (AC-19).
const EPSILON: float = 1e-6

## Rule names; every validation error starts with one of these.
const RULE_Z_NEAR := "0 < z_near"
## See `RULE_Z_NEAR`.
const RULE_UNIQUE_DEPTH := "no two slots share a view depth"
## See `RULE_Z_NEAR`.
const RULE_IN_FRAME := "every actor quad inside the frame"
## See `RULE_Z_NEAR`.
const RULE_VISIBLE := "visible_share >= actor_visible_min"
## See `RULE_Z_NEAR`.
const RULE_DOF := "background blur >= z_far + dof_margin"
## See `RULE_Z_NEAR`.
const RULE_SKY := "boss horizon_frac >= sky_share_min"


## `size = h_near = 2 * near * tan(battle_fov / 2) * max(1, (16/9) / aspect)`
## (ADR-0005 §6): the frustum height on the near plane under `KEEP_HEIGHT`.
## Below 16:9 it widens so the 16:9 horizontal view is kept.
static func h_near(near: float, battle_fov_degrees: float, aspect: float) -> float:
	return 2.0 * near * tan(deg_to_rad(battle_fov_degrees) * 0.5) \
			* maxf(1.0, (16.0 / 9.0) / aspect)


## The stage's base lens shift, placing the horizon at `horizon_frac` from
## the top: `frustum_offset = (0, -(0.5 - horizon_frac) * h_near)` (ADR-0005 §6).
static func base_lens_shift(horizon_frac: float, p_h_near: float) -> Vector2:
	return Vector2(0.0, -(0.5 - horizon_frac) * p_h_near)


## The hit-punch's lens-shift contribution for a `hit_punch` offset of
## `punch_px` screen pixels (y down): `(-px_x * h_near / H, px_y * h_near / H)`,
## so the image moves BY `punch_px` on screen, as the GDD `hit_punch` formula
## states ("moves the whole view by `offset` whole screen pixels"). +x in
## `frustum_offset` moves the image left and +y moves it down (ADR-0005 §6,
## probed). ADR-0005 §6 as written had both signs flipped, so the image moved
## by `-punch_px`; ruled a sign error in story 024 (2026-10-30).
static func punch_lens_shift(punch_px: Vector2i, p_h_near: float, viewport_height: int) -> Vector2:
	var per_px: float = p_h_near / float(viewport_height)
	return Vector2(-float(punch_px.x) * per_px, float(punch_px.y) * per_px)


## `f_px = H / (2 * tan(F_v_eff / 2))`, the vertical focal length in pixels.
static func f_px(battle_fov_degrees: float, aspect: float, viewport_height: int) -> float:
	var f_v_eff: float = FovMath.effective_vertical_fov_degrees(battle_fov_degrees, aspect)
	return float(viewport_height) / (2.0 * tan(deg_to_rad(f_v_eff) * 0.5))


## `y_foot(z) = y_h + h_cam * f_px / z`, with `y_h = horizon_frac * H`: the
## row (from the top) of a foot anchor at view depth `z`.
static func y_foot(z: float, h_cam: float, horizon_frac: float, p_f_px: float,
		viewport_height: int) -> float:
	return horizon_frac * float(viewport_height) + h_cam * p_f_px / z


## The battle camera's `CameraState` for `stage` at `viewport_size`, with an
## optional hit-punch of `punch_px` (the same matrix `DioramaStage` drives).
static func camera_state(stage: BattleStage, config: PresentationConfig,
		viewport_size: Vector2i, punch_px: Vector2i = Vector2i.ZERO) -> SpriteProjection.CameraState:
	var aspect: float = float(viewport_size.x) / float(viewport_size.y)
	var size: float = h_near(config.battle_camera_near, config.battle_fov_degrees, aspect)
	var offset: Vector2 = base_lens_shift(stage.horizon_frac, size) \
			+ punch_lens_shift(punch_px, size, viewport_size.y)
	return SpriteProjection.CameraState.from_frustum(stage.camera_transform(), size, aspect,
			offset, config.battle_camera_near, config.battle_camera_far)


## Every slot's on-screen quad at `viewport_size` (the idle frame at `T`).
static func slot_rects(stage: BattleStage, config: PresentationConfig,
		viewport_size: Vector2i) -> Array[Rect2i]:
	var cam: SpriteProjection.CameraState = camera_state(stage, config, viewport_size)
	var out: Array[Rect2i] = []
	for i: int in stage.slots.size():
		out.append(SpriteProjection.screen_rect(stage.slot_anchor(i), cam,
				stage.actor_frame_size, viewport_size, config.texel_base_lines))
	return out


## Whether `rect` lies fully inside a `viewport_size` frame.
static func rect_in_frame(rect: Rect2i, viewport_size: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, viewport_size).encloses(rect)


## Each slot's `visible_share` at `viewport_size`, every slot filled: the
## share of its quad not covered by the quad of any slot with a smaller view
## depth, nor by the projected bounds (`SpriteProjection.screen_bounds`) of
## any `stage.occluders` box whose nearest face is nearer than the slot (GDD
## `battle_framing`, "Visible share"; stories 022, 047). Rectangles make it
## conservative.
static func visible_shares(stage: BattleStage, config: PresentationConfig,
		viewport_size: Vector2i = DEFAULT_VIEWPORT) -> PackedFloat64Array:
	var rects: Array[Rect2i] = slot_rects(stage, config, viewport_size)
	var cam: SpriteProjection.CameraState = camera_state(stage, config, viewport_size)
	var occluder_rects: Array[Rect2i] = []
	var occluder_depths: Array[float] = []
	for box: AABB in stage.occluders:
		occluder_rects.append(SpriteProjection.screen_bounds(box, cam, viewport_size))
		occluder_depths.append(-box.end.z)
	var shares := PackedFloat64Array()
	for i: int in rects.size():
		var clipped: Array[Rect2i] = []
		for j: int in rects.size():
			if j != i and stage.slot_depth(j) < stage.slot_depth(i) \
					and rects[i].intersects(rects[j]):
				clipped.append(rects[i].intersection(rects[j]))
		for k: int in occluder_rects.size():
			if occluder_depths[k] < stage.slot_depth(i) and rects[i].intersects(occluder_rects[k]):
				clipped.append(rects[i].intersection(occluder_rects[k]))
		var area: int = rects[i].get_area()
		if area <= 0:
			shares.append(0.0)
		else:
			shares.append(1.0 - float(union_area(clipped)) / float(area))
	return shares


## The exact area covered by the union of `rects` (coordinate compression).
static func union_area(rects: Array[Rect2i]) -> int:
	if rects.is_empty():
		return 0
	var xs: Array[int] = []
	var ys: Array[int] = []
	for r: Rect2i in rects:
		xs.append(r.position.x)
		xs.append(r.end.x)
		ys.append(r.position.y)
		ys.append(r.end.y)
	xs.sort()
	ys.sort()
	var total: int = 0
	for xi: int in xs.size() - 1:
		for yi: int in ys.size() - 1:
			var cell := Rect2i(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi])
			if cell.get_area() == 0:
				continue
			for r: Rect2i in rects:
				if r.encloses(cell):
					total += cell.get_area()
					break
	return total


## Slot index pairs `(a, b)` whose view depths are equal within `EPSILON`
## (story 046: they would render with ambiguous depth order).
static func depth_collisions(stage: BattleStage) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for a: int in stage.slots.size():
		for b: int in range(a + 1, stage.slots.size()):
			if absf(stage.slot_depth(a) - stage.slot_depth(b)) <= EPSILON:
				out.append(Vector2i(a, b))
	return out


## Runs `battle_framing`'s load checks (GDD Formulas, Edge Cases; AC-19,
## AC-42, AC-46) and returns one content error per broken rule, each starting
## with its `RULE_*` name and naming the stage; empty means the stage passes.
static func validate(stage: BattleStage, config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var sid: String = String(stage.stage_id)
	if stage.slots.is_empty():
		errors.append("%s -- stage '%s' has no slots" % [RULE_Z_NEAR, sid])
		return errors
	var z_near: float = INF
	var z_far: float = -INF
	for i: int in stage.slots.size():
		z_near = minf(z_near, stage.slot_depth(i))
		z_far = maxf(z_far, stage.slot_depth(i))
	if z_near <= 0.0:
		errors.append("%s -- stage '%s' has z_near %.4f" % [RULE_Z_NEAR, sid, z_near])
		return errors
	for pair: Vector2i in depth_collisions(stage):
		errors.append("%s -- stage '%s' slots %d and %d share depth %.4f"
				% [RULE_UNIQUE_DEPTH, sid, pair.x, pair.y, stage.slot_depth(pair.x)])
	for vp: Vector2i in SUPPORTED_VIEWPORTS:
		var rects: Array[Rect2i] = slot_rects(stage, config, vp)
		for i: int in rects.size():
			if not rect_in_frame(rects[i], vp):
				errors.append("%s -- stage '%s' slot %d at %dx%d: %s"
						% [RULE_IN_FRAME, sid, i, vp.x, vp.y, rects[i]])
	var shares: PackedFloat64Array = visible_shares(stage, config)
	for i: int in shares.size():
		if shares[i] < config.actor_visible_min - EPSILON:
			errors.append("%s -- stage '%s' slot %d visible_share %.4f"
					% [RULE_VISIBLE, sid, i, shares[i]])
	if stage.background_blur_begin < z_far + config.dof_margin - EPSILON:
		errors.append("%s -- stage '%s' blur at %.4f, z_far %.4f"
				% [RULE_DOF, sid, stage.background_blur_begin, z_far])
	if stage.is_boss and stage.horizon_frac < config.sky_share_min - EPSILON:
		errors.append("%s -- stage '%s' horizon_frac %.4f"
				% [RULE_SKY, sid, stage.horizon_frac])
	return errors
