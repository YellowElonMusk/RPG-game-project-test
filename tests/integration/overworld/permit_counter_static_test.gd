## Story 091, AC-33d (GDD rule 13a): the Permit Counter is Static and
## notices nothing; 10 s of overlap starts nothing and plays "Take a number."
## exactly once; the prompt shows the ticket; `confirm` starts its fight.
## After Fled: not stunned or pushed, the leader on its return marker in a
## SAFE cell, the "number called" line opens on `transition_finished` and a
## mashed confirm cannot skip it, the boom stays closed, and nothing starts
## until a fresh `confirm`. The counter has been seen from the camp side
## (its decree is active). Drives the real `GameRoot`.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DUNGEON: String = "map_paris_dungeon_placeholder"
const _SYM: String = "sym_paris_permit_counter"
const _DT: float = 1.0 / 60.0


func test_counter_is_deaf_and_touching_it_only_barks_once() -> void:
	var root: GameRoot = _boot()
	var dungeon: OverworldMode = _enter_dungeon(root)
	var source: EncounterSource = dungeon.get_encounter_sources()[0]
	var barks: Array[String] = []
	dungeon.barked.connect(func(text: String, _at: Vector2) -> void: barks.append(text))
	dungeon.grace_active = false
	dungeon.set_leader_position(source.brain.position + Vector2(0.0, 0.5))
	for i: int in ceili(10.0 / _DT):
		dungeon.step_frame(_DT, Vector2.ZERO)
	assert_int(root.machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(dungeon.encounter_requests).is_equal(0)
	assert_int(source.brain.sub_state).is_equal(SymbolBrain.SubState.STATIC)
	assert_array(barks).is_equal(["Take a number."])
	# Leaving and touching again never repeats it.
	dungeon.set_leader_position(source.brain.position + Vector2(0.0, 3.0))
	dungeon.step_frame(_DT, Vector2.ZERO)
	dungeon.set_leader_position(source.brain.position + Vector2(0.0, 0.5))
	dungeon.step_frame(_DT, Vector2.ZERO)
	assert_int(barks.size()).is_equal(1)


func test_prompt_shows_the_ticket_and_confirm_starts_the_fight() -> void:
	var root: GameRoot = _boot()
	var dungeon: OverworldMode = _enter_dungeon(root)
	var source: EncounterSource = dungeon.get_encounter_sources()[0]
	dungeon.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	dungeon.set_leader_facing(Vector2.UP)
	assert_str(String(dungeon.probe_kind())).is_equal("ticket")
	assert_bool(dungeon.handle_action(InputActions.CONFIRM, true)).is_true()
	assert_int(dungeon.encounter_requests).is_equal(1)
	assert_int(root.machine.phase).is_not_equal(GameStateMachine.Phase.IDLE)


func test_fled_returns_to_the_marker_and_the_number_called_line_is_guarded() -> void:
	var root: GameRoot = _boot()
	var dungeon: OverworldMode = _enter_dungeon(root)
	var map: OverworldMap = dungeon.get_map()
	var marker: EncounterSymbol = map.symbol_markers()[0]
	var source: EncounterSource = dungeon.get_encounter_sources()[0]
	var counter_at: Vector2 = source.brain.position
	dungeon.set_leader_position(counter_at + Vector2(0.0, 1.0))
	dungeon.set_leader_facing(Vector2.UP)
	dungeon.handle_action(InputActions.CONFIRM, true)
	_run_to_idle(root.machine)
	assert_object(root.current_mode_node() as BattleMode).is_not_null()
	assert_int(root.machine.report_battle_outcome(GameStateMachine.BattleResult.FLED)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)

	assert_bool(is_same(root.current_mode_node(), dungeon)).is_true()
	assert_vector(dungeon.get_leader_position()).is_equal(marker.return_marker)
	var grid: WalkGrid = dungeon.get_walk_grid()
	assert_bool(grid.is_safe(grid.cell_of(dungeon.get_leader_position()))).is_true()
	assert_int(source.brain.sub_state).is_equal(SymbolBrain.SubState.STATIC)
	assert_vector(source.brain.position).is_equal(counter_at)
	assert_bool(dungeon.is_checkpoint_open(&"cp_permit_boom")).is_false()
	# The line is up on the reveal; a confirm inside input_guard is refused.
	assert_array(root.machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_object(line).is_not_null()
	assert_str(line.text).contains("Your number was called")
	line.handle_action(InputActions.CONFIRM, true)
	assert_array(root.machine.overlay_stack).is_not_empty()
	line.advance_guard(0.2)
	line.handle_action(InputActions.CONFIRM, true)
	assert_array(root.machine.overlay_stack).is_empty()
	# Nothing restarts the fight but a new confirm at the counter.
	var requests: int = dungeon.encounter_requests
	for i: int in 30:
		dungeon.step_frame(_DT, Vector2.ZERO)
	assert_int(dungeon.encounter_requests).is_equal(requests)
	assert_int(root.machine.phase).is_equal(GameStateMachine.Phase.IDLE)


func test_counter_is_first_seen_from_the_camp_edge() -> void:
	var root: GameRoot = _boot()
	var dungeon: OverworldMode = _enter_dungeon(root)
	var map: OverworldMap = dungeon.get_map()
	assert_bool(dungeon.is_first_seen(_SYM)).is_false()
	var camp: Vector2 = map.camp_spots()[0].ground_position(map)
	var counter: Vector2 = map.symbol_markers()[0].patrol_path[0]
	dungeon.set_leader_position(camp + (counter - camp).normalized() * (dungeon.config.safe_radius_m - 0.2))
	dungeon.step_frame(_DT, Vector2.ZERO)
	assert_bool(dungeon.is_first_seen(_SYM)).is_true()
	assert_bool(root.world_state.has_flag("seen:" + _SYM)).is_true()


func _enter_dungeon(root: GameRoot) -> OverworldMode:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(_DUNGEON, &"from_segment"))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var dungeon: OverworldMode = root.current_mode_node() as OverworldMode
	dungeon.set_process(false)
	return dungeon


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks").is_true()
