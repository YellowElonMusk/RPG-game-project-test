## Pure, testable replay of the leader's recorded path for cosmetic
## followers (GDD `design/gdd/overworld-exploration-encounters.md` Formulas,
## `follower_trail`; GDD rule 2: "Followers have no collision and no logic,
## and nothing can touch them" -- this class never reads the leader's
## collision state, only the positions `OverworldMode` hands it). Not a
## `Node`: nothing here reads the scene tree, so it is driven and asserted
## against directly from a unit test as well as from `OverworldMode`, which
## owns one instance per party and calls `step()` once a frame (story 006).
##
## The formula, verbatim from the GDD: "each frame, walk the leader's
## segment [p_prev, p_leader] and append a point every trail_sample_m of arc
## length; pos_i = point at arc length s_i = i * follower_spacing_m back
## along [p_leader, trail newest->oldest]; N_buf = ceil(n_f *
## follower_spacing_m / trail_sample_m - epsilon) + 2".
class_name FollowerTrail
extends RefCounted

## Guards the formula's buffer-size ceiling against floating-point
## round-up at an exact multiple of `trail_sample_m`, and the resampling
## loop's own boundary check (GDD Formulas, `follower_trail`, `epsilon`).
const _EPSILON: float = 1e-6

## Recorded trail points, oldest first, resampled to `trail_sample_m` arc
## length apart (`_append_samples()`) and then capped to the formula's
## `N_buf` (`_trim()`) so this buffer grows with follower count and the
## config's own knobs, never with frame count.
var _points: Array[Vector2] = []

## The leader's position as of the last `step()` (or `reset()`) call -- the
## start of the next frame's segment to resample.
var _prev_pos: Vector2 = Vector2.ZERO

## Arc length already walked past the last appended trail point, carried
## across frames so sampling spacing stays exactly `trail_sample_m`
## regardless of how a given frame's segment lands on that grid (GDD
## Formulas, Output Range: points are "sub-sampled inside each frame's
## segment, so spacing never exceeds trail_sample_m, however long the frame
## is").
var _carry_m: float = 0.0

## `false` until the first `reset()` (explicit, or implicit on the first
## `step()`) -- guards against resampling from a stale `_prev_pos`.
var _initialized: bool = false


## Clears the trail and anchors it at `leader_pos`, with no recorded
## history. Story 007's map-entry/teleport/redirect/thaw reset is this call
## (out of scope here); `step()` calls this itself on its first invocation,
## so a caller that never resets still gets a trail anchored wherever the
## leader started, rather than resampling a phantom segment from the
## origin.
func reset(leader_pos: Vector2) -> void:
	_points = []
	_prev_pos = leader_pos
	_carry_m = 0.0
	_initialized = true


## Advances the trail by the leader's move since the last call
## (`_prev_pos` -> `leader_pos`) and returns `n_followers` positions,
## nearest follower first: index `i` is at arc length `(i + 1) *
## follower_spacing_m` behind the leader (the formula's `pos_i`, which is
## 1-indexed; this array is 0-indexed, so `pos_1` is `result[0]`).
##
## Followers move with the leader's travelled distance, not with time
## (GDD Formulas, `follower_trail`): calling this again with an unchanged
## `leader_pos` (the leader stopped) appends no new trail points and
## returns the same positions as the previous call -- GDD AC-4's "every
## follower stops on the same frame" falls out of this directly, with no
## separate stop handling.
func step(leader_pos: Vector2, n_followers: int, cfg: OverworldConfig) -> Array[Vector2]:
	if not _initialized:
		reset(leader_pos)
	_append_samples(_prev_pos, leader_pos, cfg.trail_sample_m)
	_prev_pos = leader_pos
	_trim(_buffer_capacity(n_followers, cfg))

	var result: Array[Vector2] = []
	for i in range(n_followers):
		var target_m: float = float(i + 1) * cfg.follower_spacing_m
		result.append(_position_at_arc_length(leader_pos, target_m))
	return result


## The trail buffer's current length, for the formula's `N_buf` acceptance
## check (GDD AC-4: "the buffer length equals N_buf").
func buffer_length() -> int:
	return _points.size()


## Resamples the just-walked segment `[p_prev, p_leader]` at `sample_m` arc
## length, carrying any leftover distance from the previous call into
## `_carry_m` so spacing stays exactly `sample_m` across frame boundaries
## (GDD Formulas, `follower_trail`, Output Range). A zero-length segment
## (the leader didn't move) appends nothing and leaves `_carry_m` untouched.
func _append_samples(p_prev: Vector2, p_leader: Vector2, sample_m: float) -> void:
	var seg: Vector2 = p_leader - p_prev
	var seg_len: float = seg.length()
	if seg_len <= 0.0:
		return
	var dir: Vector2 = seg / seg_len
	var last_offset: float = -_carry_m
	var offset: float = sample_m - _carry_m
	while offset <= seg_len + _EPSILON:
		_points.append(p_prev + dir * offset)
		last_offset = offset
		offset += sample_m
	_carry_m = seg_len - last_offset


## Drops the oldest points past `capacity` (the formula's `N_buf`) so the
## buffer never grows with frame count.
func _trim(capacity: int) -> void:
	var excess: int = _points.size() - capacity
	if excess > 0:
		_points = _points.slice(excess)


## The formula's `N_buf`: `ceil(n_followers * follower_spacing_m /
## trail_sample_m - epsilon) + 2` (GDD Formulas, `follower_trail`).
func _buffer_capacity(n_followers: int, cfg: OverworldConfig) -> int:
	var raw: float = float(n_followers) * cfg.follower_spacing_m / cfg.trail_sample_m - _EPSILON
	return ceili(raw) + 2


## Walks backward from `leader_pos` (arc length 0, not itself stored -- the
## formula's "[p_leader, trail newest->oldest]") through the trail, newest
## point first, to the position at arc length `target_m` behind the leader
## (the formula's `pos_i`), linearly interpolating between the two
## bracketing points. A pair that straddles a direction change (a corner)
## is where a follower "cuts the corner" by up to half a sample spacing
## (GDD Formulas, Output Range) -- this is the one place the result departs
## from the leader's exact walked polyline, and only by that bound.
##
## If the trail hasn't recorded `target_m` of history yet (only possible
## just after a `reset()`, before the party has walked far enough), holds
## at the oldest recorded point -- exactly where the leader was when the
## party started walking, the right answer for "hasn't walked that far
## yet."
func _position_at_arc_length(leader_pos: Vector2, target_m: float) -> Vector2:
	var prev_point: Vector2 = leader_pos
	var walked_m: float = 0.0
	for i in range(_points.size() - 1, -1, -1):
		var point: Vector2 = _points[i]
		var seg_len: float = prev_point.distance_to(point)
		if walked_m + seg_len >= target_m:
			var remaining_m: float = target_m - walked_m
			var t: float = remaining_m / seg_len if seg_len > 0.0 else 0.0
			return prev_point.lerp(point, t)
		walked_m += seg_len
		prev_point = point
	return prev_point
