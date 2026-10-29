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
	# (outward normal, distance from the focus to the edge line)
	var edges: Array = [
		[Vector2(0, 1), fp.a_near],
		[Vector2(0, -1), fp.a_far],
		[n_side, d_side],
		[Vector2(-n_side.x, n_side.y), d_side],
	]
	var reach: float = INF
	for edge: Array in edges:
		var n: Vector2 = edge[0]
		var r_e: float = float(edge[1]) - (absf(n.x) * dz_x + absf(n.y) * dz_y) - lag
		var along: float = n.dot(d)
		if along > 1e-9:
			reach = minf(reach, r_e / along)
	return reach
