## Story 123, AC-51d (GDD rule 16): the `optional_teach` bark fires when
## the leader comes within `interact_reach_m * 2` of its speaker, with no
## input, and never slows the leader. It does not fire again until the
## leader has gone beyond twice that distance, then fires on re-entry.
## `confirm` at the speaker shows the same line. A bark due while the name
## card shows waits until the card is cleared. Uses the segment's café
## regular.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0


func test_fires_on_approach_without_input_and_never_blocks() -> void:
	var ctx: Array = _mode()
	var mode: OverworldMode = ctx[0]
	var barks: Array[String] = ctx[1]
	var npc: NpcSpawn = mode.get_map().npc_spawns()[0]
	var at: Vector2 = npc.ground_position(mode.get_map())
	var near: float = mode.config.interact_reach_m * 2.0
	mode.set_leader_position(at + Vector2(-(near + 0.5), 0.0))  # open floor to the west
	mode.step_frame(_DT, Vector2.ZERO)
	assert_array(barks).is_empty()
	# Walk toward the speaker; the walk speed is unchanged frame to frame.
	var fired_at: float = -1.0
	for i: int in 30:
		mode.step_frame(_DT, Vector2.RIGHT)
		assert_float(mode.get_last_distance_moved()).is_equal_approx(mode.config.walk_speed * _DT, 1e-4)
		if fired_at < 0.0 and not barks.is_empty():
			fired_at = mode.get_leader_position().distance_to(at)
	assert_array(barks).is_equal([npc.line])
	assert_float(fired_at).is_less_equal(near)
	assert_array(mode.lines_said).is_empty()


func test_rearms_only_beyond_twice_the_distance() -> void:
	var ctx: Array = _mode()
	var mode: OverworldMode = ctx[0]
	var barks: Array[String] = ctx[1]
	var at: Vector2 = mode.get_map().npc_spawns()[0].ground_position(mode.get_map())
	var near: float = mode.config.interact_reach_m * 2.0
	_stand(mode, at + Vector2(0.0, near - 0.1))
	assert_int(barks.size()).is_equal(1)
	# Out to just inside twice the distance, back in: no second bark.
	_stand(mode, at + Vector2(0.0, 2.0 * near - 0.1))
	_stand(mode, at + Vector2(0.0, near - 0.1))
	assert_int(barks.size()).is_equal(1)
	# Beyond twice the distance, back in: fires again.
	_stand(mode, at + Vector2(0.0, 2.0 * near + 0.1))
	_stand(mode, at + Vector2(0.0, near - 0.1))
	assert_int(barks.size()).is_equal(2)


func test_confirm_at_the_speaker_shows_the_same_line() -> void:
	var ctx: Array = _mode()
	var mode: OverworldMode = ctx[0]
	var npc: NpcSpawn = mode.get_map().npc_spawns()[0]
	mode.set_leader_position(npc.ground_position(mode.get_map()) + Vector2(-1.0, 0.0))
	mode.set_leader_facing(Vector2.RIGHT)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(mode.lines_said).is_equal([npc.line])


func test_a_bark_due_under_the_name_card_waits_for_it() -> void:
	var ctx: Array = _mode()
	var mode: OverworldMode = ctx[0]
	var barks: Array[String] = ctx[1]
	var at: Vector2 = mode.get_map().npc_spawns()[0].ground_position(mode.get_map())
	mode.name_card_showing = true
	_stand(mode, at + Vector2(0.0, 1.0))
	_stand(mode, at + Vector2(0.0, 1.0))
	assert_array(barks).is_empty()
	mode.name_card_showing = false
	_stand(mode, at + Vector2(0.0, 1.0))
	assert_int(barks.size()).is_equal(1)


func _stand(mode: OverworldMode, at: Vector2) -> void:
	mode.set_leader_position(at)
	mode.step_frame(_DT, Vector2.ZERO)


func _mode() -> Array:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	mode.grace_active = true
	var barks: Array[String] = []
	mode.barked.connect(func(text: String, _at: Vector2) -> void: barks.append(text))
	return [mode, barks]
