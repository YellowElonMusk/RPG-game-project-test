## Story 089, AC-33b (GDD rules 13, 13a): after passing the pre-dungeon
## CampSpot's safe zone without resting, a Defeat by the boss then Retreat
## lands the party at the pre-dungeon camp, and the boss is unresolved. With
## no camp registered yet, Retreat goes to the Town café. Drives the real
## `GameRoot`, through the interim Camp mode and back out to the overworld.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _TOWN: String = "map_paris_town_placeholder"
const _DUNGEON: String = "map_paris_dungeon_placeholder"
const _CHAMBER: String = "map_paris_boss_chamber_placeholder"
const _BOSS_SYM: String = "sym_paris_supervisor"
const _DT: float = 1.0 / 60.0


func test_retreat_after_passing_the_pre_dungeon_camp_returns_there() -> void:
	var root: GameRoot = _boot()
	_new_game(root)
	var dungeon: OverworldMode = _go(root, _DUNGEON, &"from_segment")
	# Walk through the camp's safe zone without resting.
	var camp: Vector2 = dungeon.get_map().camp_spots()[0].ground_position(dungeon.get_map())
	dungeon.set_leader_position(camp + Vector2(dungeon.config.safe_radius_m + 0.5, 0.0))
	for i: int in 40:
		dungeon.step_frame(_DT, Vector2.LEFT)
	assert_str(root.machine.last_camp_id).is_equal("camp_paris_pre_dungeon")
	_lose_to_the_boss_and_retreat(root)

	var camp_mode: InterimCampMode = root.current_mode_node() as InterimCampMode
	assert_object(camp_mode).is_not_null()
	assert_str(camp_mode.camp_id).is_equal("camp_paris_pre_dungeon")
	assert_bool(root.world_state.is_resolved(_CHAMBER, _BOSS_SYM)).is_false()
	var back: OverworldMode = _set_out(root, camp_mode)
	assert_str(back.get_map().map_id).is_equal(_DUNGEON)
	var entry: EntryPoint = back.get_map().find_entry_point(&"from_segment")
	assert_vector(back.get_leader_position()).is_equal(entry.ground_position(back.get_map()))
	assert_bool(root.world_state.is_resolved(_CHAMBER, _BOSS_SYM)).is_false()


func test_retreat_with_no_camp_registered_goes_to_the_town_cafe() -> void:
	var root: GameRoot = _boot()
	_new_game(root)
	assert_str(root.machine.last_camp_id).is_empty()
	_lose_to_the_boss_and_retreat(root)
	var camp_mode: InterimCampMode = root.current_mode_node() as InterimCampMode
	assert_object(camp_mode).is_not_null()
	var back: OverworldMode = _set_out(root, camp_mode)
	assert_str(back.get_map().map_id).is_equal(_TOWN)
	var cafe: CampSpot = back.get_map().camp_spots()[0]
	assert_bool(cafe.is_region_default).is_true()
	var entry: EntryPoint = back.get_map().find_entry_point(cafe.return_entry_id)
	assert_vector(back.get_leader_position()).is_equal(entry.ground_position(back.get_map()))


## Enters the boss chamber, walks into the Supervisor, loses and retreats.
func _lose_to_the_boss_and_retreat(root: GameRoot) -> void:
	var chamber: OverworldMode = _go(root, _CHAMBER, &"from_dungeon")
	chamber.grace_active = false
	var frames: int = 0
	while root.machine.phase == GameStateMachine.Phase.IDLE and frames < 600:
		chamber.step_frame(_DT, Vector2.UP)
		frames += 1
	_run_to_idle(root.machine)
	assert_object(root.current_mode_node() as BattleMode).is_not_null()
	assert_int(root.machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_int(root.machine.choose_retreat()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)


func _set_out(root: GameRoot, camp_mode: InterimCampMode) -> OverworldMode:
	assert_bool(camp_mode.handle_action(InputActions.CONFIRM, true)).is_true()
	_run_to_idle(root.machine)
	var back: OverworldMode = root.current_mode_node() as OverworldMode
	assert_object(back).is_not_null()
	back.set_process(false)
	return back


func _go(root: GameRoot, map_id: String, entry: StringName) -> OverworldMode:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(map_id, entry))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var mode: OverworldMode = root.current_mode_node() as OverworldMode
	mode.set_process(false)
	return mode


func _new_game(root: GameRoot) -> void:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	(root.current_mode_node() as OverworldMode).set_process(false)


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
