## Story 100, AC-40 (GDD Edge Cases, `frame_step_safety`): a 0.25 s frame
## advances every timer by exactly `dt_max`; swept contact over approach
## angles 0°-90° (15° steps), lateral offsets 0 to 2*body_radius and both
## bodies at full speed fires exactly for the pairs whose closest approach is
## within 2*body_radius; zero relative displacement uses `|a|` with no
## division; a leader at `walk_speed` never crosses a 1-cell wall.
extends GdUnitTestSuite

const _DT_MAX: float = 0.10


func test_a_long_frame_advances_every_timer_by_dt_max() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	mode.set("_grace_left", 2.0)
	mode.grace_active = true
	mode.call(&"_start_bark", "A bark.")
	mode._process(0.25)
	assert_float(mode.get_grace_left()).is_equal_approx(2.0 - _DT_MAX, 1e-6)
	assert_float(float(mode.get("_bark_elapsed"))).is_equal_approx(_DT_MAX, 1e-6)


func test_swept_contact_matches_the_true_closest_approach() -> void:
	var cfg := OverworldConfig.new()
	var r2: float = 2.0 * cfg.body_radius
	var leader_step: float = cfg.walk_speed * _DT_MAX
	var symbol_step: float = cfg.v_chase() * _DT_MAX
	var contacts: int = 0
	var misses: int = 0
	for deg: int in range(0, 91, 15):
		for k: int in 9:
			var lateral: float = r2 * k / 8.0
			# The leader walks +x; the symbol comes at `deg` from the leader's
			# path, aimed to pass `lateral` metres off the leader mid-frame.
			var leader_from := Vector2.ZERO
			var leader_delta := Vector2(leader_step, 0.0)
			var dir: Vector2 = Vector2.from_angle(deg_to_rad(180.0 + deg))
			var meet: Vector2 = leader_from + leader_delta * 0.5 + dir.orthogonal() * lateral
			var symbol_delta: Vector2 = dir * symbol_step
			var symbol_from: Vector2 = meet - symbol_delta * 0.5
			var truth: float = _brute_closest(leader_from, leader_delta, symbol_from, symbol_delta)
			var swept: float = OverworldMode.closest_approach(leader_from, leader_delta, symbol_from, symbol_delta)
			assert_float(swept).is_equal_approx(truth, 1e-3)
			assert_bool(swept <= r2).override_failure_message("angle %d lateral %.2f: swept %.3f truth %.3f"
					% [deg, lateral, swept, truth]).is_equal(truth <= r2)
			if truth <= r2:
				contacts += 1
			else:
				misses += 1
	# The fixture set exercises both outcomes.
	assert_int(contacts).is_greater(0)
	assert_int(misses).is_greater(0)


func test_zero_relative_displacement_uses_the_start_distance() -> void:
	var a := Vector2(0.5, 0.2)
	var same := Vector2(0.3, 0.1)
	# Both bodies move by the same vector: b = 0, no division.
	assert_float(OverworldMode.closest_approach(a, same, Vector2.ZERO, same)).is_equal(a.length())
	assert_float(OverworldMode.closest_approach(a, Vector2.ZERO, Vector2.ZERO, Vector2(5e-5, 0.0))).is_equal(a.length())


func test_a_leader_at_walk_speed_never_crosses_a_one_cell_wall() -> void:
	var cfg := OverworldConfig.new()
	var grid: WalkGrid = ContactFixture.open_grid()
	var wall: Array[Vector2i] = []
	for y: int in grid.size.y:
		wall.append(Vector2i(6, y))
	grid.set_blocked(wall, true)
	for angle: int in range(-60, 61, 15):
		var pos := Vector2(3.5, 6.5)
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(angle))
		for i: int in 120:
			pos = GroundMover.step(pos, dir, _DT_MAX, grid, cfg, cfg.walk_speed, 0, true).position
			assert_float(pos.x).override_failure_message("angle %d crossed the wall" % angle).is_less(6.0)


## Closest approach by fine sampling (the reference the swept test must match).
func _brute_closest(lf: Vector2, ld: Vector2, sf: Vector2, sd: Vector2) -> float:
	var best: float = INF
	for i: int in 2001:
		var t: float = i / 2000.0
		best = minf(best, (lf + ld * t).distance_to(sf + sd * t))
	return best
