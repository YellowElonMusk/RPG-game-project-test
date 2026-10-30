## Story 081, AC-30g (GDD rule 11, map exits): a leader placed inside a
## MapExit rectangle by a load fires no exit until it has left the
## rectangle and entered it again; and a `move` held for `ceil(2/dt)`
## frames across a real map change never carries the leader back across.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DT: float = 1.0 / 60.0


func test_a_leader_loaded_inside_an_exit_fires_only_after_leaving_and_reentering() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([], RequestSpyMachine.new()))
	var exit: MapExit = _exit(mode, &"exit_to_town")
	var inside: Vector2 = exit.trigger_rect.get_center()
	mode.grace_active = false
	mode.set_leader_position(inside)
	var fired: Array[StringName] = []
	mode.map_exit_requested.connect(func(id: StringName) -> void: fired.append(id))
	# Moving about inside the rectangle fires nothing.
	for i: int in 10:
		mode.step_frame(_DT, Vector2.DOWN if i % 2 == 0 else Vector2.UP)
	assert_array(fired).is_empty()
	# Walk out (east, into the map), then back in (west).
	var frames: int = 0
	while exit.trigger_rect.has_point(mode.get_leader_position()) and frames < 120:
		mode.step_frame(_DT, Vector2.RIGHT)
		frames += 1
	assert_bool(exit.trigger_rect.has_point(mode.get_leader_position())).is_false()
	assert_array(fired).is_empty()
	frames = 0
	while fired.is_empty() and frames < 120:
		mode.step_frame(_DT, Vector2.LEFT)
		frames += 1
	assert_array(fired).is_equal([&"exit_to_town"])


func test_a_move_held_across_a_map_change_never_crosses_back() -> void:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = "user://test_saves_081"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	town.tick_timed_text(60.0)
	# Walk east into the Town's exit to the segment, holding the move
	# through the map change and for ceil(2/dt) frames after it.
	var exit: MapExit = _exit(town, &"exit_to_segment")
	town.set_leader_position(exit.trigger_rect.get_center() + Vector2(-1.5, 0.0))
	var hold: int = ceili(2.0 / _DT)
	var frames: int = 0
	while root.machine.phase == GameStateMachine.Phase.IDLE and frames < 120:
		town.step_frame(_DT, Vector2.RIGHT)
		frames += 1
	var held_after: int = 0
	while held_after < hold:
		root.machine.tick(_DT)
		var current: OverworldMode = root.current_mode_node() as OverworldMode
		if current != null and current != town:
			current.set_process(false)
			current.step_frame(_DT, Vector2.RIGHT)
			held_after += 1
	var segment: OverworldMode = root.current_mode_node() as OverworldMode
	assert_str(segment.get_map().map_id).is_equal("map_paris_segment_placeholder")
	assert_int(segment.exit_requests).is_equal(0)
	assert_int(root.machine.phase).is_equal(GameStateMachine.Phase.IDLE)


func _exit(mode: OverworldMode, id: StringName) -> MapExit:
	for exit: MapExit in mode.get_map().map_exits():
		if exit.marker_id == id:
			return exit
	return null


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
