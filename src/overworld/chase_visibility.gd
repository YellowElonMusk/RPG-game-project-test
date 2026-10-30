## The overworld camera's guaranteed on-screen distance from the leader
## (GDD Formulas `chase_visibility`, I14). Pure static. The footprint is the
## follow camera's ground trapezoid around its focus: the near edge `a_near`
## toward the camera (ground +y, the camera's yaw is 0), the far edge
## `a_far` away from it (ground -y), half-widths `w_near` and `w_far`. Each
## edge is pulled in by the dead zone's reach along its normal
## (`|n_x| * dz_x + |n_y| * dz_y`) and the follow lag `walk_speed * tau`:
##
## `R_e = dist_e - (|n_e,x| * dz_x + |n_e,y| * dz_y) - walk_speed * tau`
##
## `edge_reach()` gives that guaranteed distance along one ground direction,
## the smallest over the supported aspects (story 075's telegraph check:
## "the visibility edge `R_e` in its direction"). The full I14 validation
## (story 099) builds on the same edges.
##
## Usage example:
## [codeblock]
## var r: float = ChaseVisibility.edge_reach(dir, PresentationConfig.new(), cfg.walk_speed)
## [/codeblock]
class_name ChaseVisibility
extends RefCounted

## The supported aspects (GDD: 4:3, 16:9 and 21:9; 16:10 lies between).
const ASPECTS: Array[float] = [4.0 / 3.0, 16.0 / 9.0, 21.0 / 9.0]


## The guaranteed on-screen distance from the leader along ground direction
## `dir`, the smallest over `ASPECTS`, for `presentation`'s follow camera.
static func edge_reach(dir: Vector2, presentation: PresentationConfig, walk_speed: float) -> float:
	var best: float = INF
	for aspect: float in ASPECTS:
		best = minf(best, edge_reach_at(dir, presentation, walk_speed, aspect))
	return best


## `edge_reach()` at one `aspect`: the distance from the focus along `dir`
## to the shrunk footprint's boundary.
static func edge_reach_at(dir: Vector2, presentation: PresentationConfig, walk_speed: float,
		aspect: float) -> float:
	if dir.is_zero_approx():
		return INF
	var d: Vector2 = dir.normalized()
	var reach: float = INF
	for edge: Array in _edges(presentation, walk_speed, aspect):
		var n: Vector2 = edge[0]
		var r_e: float = edge[2]
		var along: float = n.dot(d)
		if along > 1e-9:
			reach = minf(reach, r_e / along)
	return reach


## The aspect names used in I14 errors, matching `ASPECTS`.
const ASPECT_NAMES: Array[String] = ["4:3", "16:9", "21:9"]
## Edge names in `_edges()` order.
const EDGE_NAMES: Array[String] = ["near", "far", "side", "side"]


## I14 (GDD Formulas `chase_visibility`; story 099): at every supported
## aspect `R_vis = min_e R_e >= see_m`, and when `profile` blurs, the
## tilt-shift keeps every point within `see_m` of the leader sharp:
## `dof_near_end <= d_cam(-s_blur) - H_max * sin(pitch)` and
## `dof_far_begin >= d_cam(+s_blur)`, with `s_blur = see_m + dz_y +
## walk_speed * tau` (measured from the leader at the dead-zone edge, not
## from the focus). Returns one error per failure, naming the aspect and
## the edge or blur bound; empty when valid.
static func validate(cfg: OverworldConfig, presentation: PresentationConfig,
		profile: LightingProfile = null) -> PackedStringArray:
	var out := PackedStringArray()
	var see: float = cfg.see_m()
	var pitch: float = deg_to_rad(presentation.follow_camera_pitch_degrees)
	for i: int in ASPECTS.size():
		var edges: Array = _edges(presentation, cfg.walk_speed, ASPECTS[i])
		var worst: int = 0
		for e: int in edges.size():
			if float(edges[e][2]) < float(edges[worst][2]):
				worst = e
		var r_vis: float = edges[worst][2]
		if r_vis < see:
			out.append("I14: at %s the %s edge R_e %.2f < see_m %.2f"
					% [ASPECT_NAMES[i], EDGE_NAMES[worst], r_vis, see])
		if profile == null:
			continue
		var s_blur: float = blur_reach(cfg, presentation, ASPECTS[i])
		if profile.dof_near_enabled:
			var limit: float = d_cam(-s_blur, presentation) \
					- presentation.overworld_card_height_max_m * sin(pitch)
			if profile.dof_near_distance > limit:
				out.append("I14: at %s dof_near_end %.2f > d_cam(-s_blur) - H_max*sin(pitch) %.2f"
						% [ASPECT_NAMES[i], profile.dof_near_distance, limit])
		if profile.dof_far_enabled:
			var far: float = d_cam(s_blur, presentation)
			if profile.dof_far_distance < far:
				out.append("I14: at %s dof_far_begin %.2f < d_cam(+s_blur) %.2f"
						% [ASPECT_NAMES[i], profile.dof_far_distance, far])
	return out


## `s_blur = see_m + dz_y + walk_speed * tau` at `aspect`: the farthest
## offset from the focus at which a symbol within `see_m` of the leader can
## be, the leader sitting at the dead-zone edge plus the follow lag.
static func blur_reach(cfg: OverworldConfig, presentation: PresentationConfig, aspect: float) -> float:
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(presentation.follow_camera_height,
			presentation.follow_camera_pitch_degrees, presentation.follow_camera_fov_degrees, aspect)
	return cfg.see_m() + presentation.follow_camera_dead_zone_fraction * fp.a_near \
			+ cfg.walk_speed * presentation.follow_camera_tau


## `d_cam(s)`: the view-space depth of the ground point `s` metres from the
## focus along the view's ground axis (+ away from the camera):
## `h / sin(pitch) + s * cos(pitch)`.
static func d_cam(s: float, presentation: PresentationConfig) -> float:
	var pitch: float = deg_to_rad(presentation.follow_camera_pitch_degrees)
	return presentation.follow_camera_height / sin(pitch) + s * cos(pitch)


## [outward normal, dist_e, R_e] for near, far and both sides at `aspect`.
static func _edges(presentation: PresentationConfig, walk_speed: float, aspect: float) -> Array:
	var h: float = presentation.follow_camera_height
	var pitch: float = deg_to_rad(presentation.follow_camera_pitch_degrees)
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(h,
			presentation.follow_camera_pitch_degrees, presentation.follow_camera_fov_degrees, aspect)
	var half_v: float = deg_to_rad(fp.f_v_eff_degrees) * 0.5
	var half_h: float = deg_to_rad(fp.f_h_degrees) * 0.5
	var w_near: float = h * cos(half_v) * tan(half_h) / sin(pitch + half_v)
	var dz_x: float = presentation.follow_camera_dead_zone_fraction * fp.w_far
	var dz_y: float = presentation.follow_camera_dead_zone_fraction * fp.a_near
	var lag: float = walk_speed * presentation.follow_camera_tau
	var span: float = fp.a_near + fp.a_far
	var side_len: float = Vector2(fp.w_far - w_near, span).length()
	var d_side: float = (w_near * span + fp.a_near * (fp.w_far - w_near)) / side_len
	var n_side := Vector2(span / side_len, (fp.w_far - w_near) / side_len)
	var out: Array = []
	for edge: Array in [[Vector2(0, 1), fp.a_near], [Vector2(0, -1), fp.a_far],
			[n_side, d_side], [Vector2(-n_side.x, n_side.y), d_side]]:
		var n: Vector2 = edge[0]
		out.append([n, edge[1], float(edge[1]) - (absf(n.x) * dz_x + absf(n.y) * dz_y) - lag])
	return out


## `R_vis = min(R_near, R_far, R_side)` over every supported aspect: the
## smallest guaranteed on-screen distance from the leader in any direction
## (story 064's clutter placement radius).
static func r_vis(presentation: PresentationConfig, walk_speed: float) -> float:
	var best: float = INF
	for aspect: float in ASPECTS:
		for edge: Array in _edges(presentation, walk_speed, aspect):
			best = minf(best, float(edge[2]))
	return best
