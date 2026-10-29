## Story 014, AC-7d (GDD rule 3 Lockouts; P2 carry-over): GIVEN a Dialogue
## line opened at an NPC, WHEN the `confirm` that closes it is pressed and
## then held for at least 10 frames, THEN the overlay closes and no new
## interaction starts while it is held; a release and a new press start
## one. Drives the real `GameRoot` routing with a synthetic input source.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DT: float = 1.0 / 60.0


func test_closing_confirm_held_starts_nothing_until_released() -> void:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	var source := SyntheticActionSource.new()
	root.machine.bind_action_source(source)
	root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	_run_to_idle(root.machine)
	root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_paris_segment_placeholder", &"from_town"))
	_run_to_idle(root.machine)
	var segment: OverworldMode = root.current_mode_node() as OverworldMode
	segment.set_process(false)
	var npc: NpcSpawn = segment.get_map().npc_spawns()[0]
	segment.set_leader_position(npc.ground_position(segment.get_map()) + Vector2(-1.0, 0.0))
	segment.set_leader_facing(Vector2.RIGHT)

	# Press: the NPC's line opens.
	source.press(InputActions.CONFIRM)
	assert_int(segment.lines_said.size()).is_equal(1)
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_object(line).is_not_null()
	source.release(InputActions.CONFIRM)
	line.advance_guard(0.2)
	# The closing press, then held for 12 frames.
	source.press(InputActions.CONFIRM)
	assert_array(root.machine.overlay_stack).is_empty()
	for i: int in 12:
		source.hold(InputActions.CONFIRM)
		root.machine.tick(_DT)
	assert_int(segment.lines_said.size()).is_equal(1)
	assert_array(root.machine.overlay_stack).is_empty()
	# Release, then a new press starts one.
	source.release(InputActions.CONFIRM)
	source.press(InputActions.CONFIRM)
	assert_int(segment.lines_said.size()).is_equal(2)
	assert_array(root.machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).is_true()
