## Story 137 (AC-137a-d): the real `GameRoot` boots New Game into
## `OverworldMode` on the placeholder Paris Town map, whose `EncounterSymbol`
## markers start real battles that thaw back (Victory, Fled, Defeat ->
## Retry). Drives the production `GameStateMachine` the way
## `game_state_game_root_boot_test.gd` does.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
## The real data root: the shipped enc_ records and squad are under test.
const _DATA_ROOT: String = "res://data"
const _TOWN_ID: String = "map_paris_town_placeholder"
## Story 138: the Clerk symbols live on the overworld segment.
const _MAP_ID: String = "map_paris_segment_placeholder"
const _DT: float = 1.0 / 60.0
const _MIN_SYMBOLS: int = 2


func test_new_game_enters_overworld_mode_with_injections() -> void:
	var root: GameRoot = _boot()
	var ow: OverworldMode = _new_game(root)
	assert_object(ow).is_not_null()
	assert_str(ow.get_map().map_id).is_equal(_TOWN_ID)
	assert_bool(is_same(ow.world_state, root.world_state)).is_true()
	assert_str(ow.world_state.map_id).is_equal(_TOWN_ID)
	assert_bool(is_same(ow.encounter_catalog, root.catalog())).is_true()
	var party: Array = ow.party_source.call()
	assert_int(party.size()).is_equal(root.catalog().all_records(&"character").size())
	var again: Array = ow.party_source.call()
	for i: int in party.size():
		assert_bool(is_same(party[i], again[i])).is_true()


func test_symbols_name_records_and_sprites_follow_brains() -> void:
	var root: GameRoot = _boot()
	var ow: OverworldMode = _new_game_on_segment(root)
	var markers: Array[EncounterSymbol] = ow.get_map().symbol_markers()
	assert_int(markers.size()).is_greater_equal(_MIN_SYMBOLS)
	for marker: EncounterSymbol in markers:
		var rec: EncounterData = root.catalog().get_record(&"encounter", marker.encounter_id) as EncounterData
		assert_object(rec).override_failure_message(marker.encounter_id).is_not_null()
		assert_bool(rec.can_flee).is_true()
		assert_int(marker.patrol_path.size()).is_greater_equal(2)
	assert_int(ow.get_encounter_sources().size()).is_equal(markers.size())
	var view: OverworldView = ow.get_node(^"OverworldView") as OverworldView
	var before: Array[Vector2] = []
	for brain: SymbolBrain in ow.get_symbol_brains():
		before.append(brain.position)
	for i: int in 30:
		ow.step_frame(_DT, Vector2.ZERO)
	view.sync_symbol_sprites()
	var sprites: Dictionary = view.get_symbol_sprites()
	assert_int(sprites.size()).is_equal(markers.size())
	var brains: Array[SymbolBrain] = ow.get_symbol_brains()
	var moved: int = 0
	for i: int in brains.size():
		var sprite: CharacterSprite = sprites[brains[i]]
		assert_vector(sprite.position).is_equal(OverworldView.ground_to_world(brains[i].position))
		if not brains[i].position.is_equal_approx(before[i]):
			moved += 1
	assert_int(moved).is_greater(0)


func test_victory_returns_to_map_without_the_symbol() -> void:
	var root: GameRoot = _boot()
	var ow: OverworldMode = _new_game_on_segment(root)
	var machine: GameStateMachine = root.machine
	var source: EncounterSource = ow.get_encounter_sources()[0]
	var battle_mode: BattleMode = _touch_and_enter_battle(root, ow, source)
	DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.VICTORY)
	battle_mode.settle_replay()
	assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_bool(is_same(root.current_mode_node(), ow)).is_true()
	assert_bool(ow.get_encounter_sources().has(source)).is_false()
	assert_bool(root.world_state.is_resolved(_MAP_ID, source.symbol_id)).is_true()
	var view: OverworldView = ow.get_node(^"OverworldView") as OverworldView
	view.sync_symbol_sprites()
	assert_int(view.get_symbol_sprites().size()).is_equal(ow.get_encounter_sources().size())


func test_fled_returns_with_the_symbol_stunned() -> void:
	var root: GameRoot = _boot()
	var ow: OverworldMode = _new_game_on_segment(root)
	var machine: GameStateMachine = root.machine
	var source: EncounterSource = ow.get_encounter_sources()[0]
	_touch_and_enter_battle(root, ow, source)
	assert_int(machine.report_battle_outcome(GameStateMachine.BattleResult.FLED)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_bool(ow.get_encounter_sources().has(source)).is_true()
	assert_int(source.brain.sub_state).is_equal(SymbolBrain.SubState.STUNNED)
	assert_bool(ow.grace_active).is_true()
	assert_bool(root.world_state.is_resolved(_MAP_ID, source.symbol_id)).is_false()


func test_defeat_retry_restarts_the_same_fight() -> void:
	var root: GameRoot = _boot()
	var ow: OverworldMode = _new_game_on_segment(root)
	var machine: GameStateMachine = root.machine
	var source: EncounterSource = ow.get_encounter_sources()[1]
	var battle_mode: BattleMode = _touch_and_enter_battle(root, ow, source)
	DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.DEFEAT)
	battle_mode.settle_replay()
	assert_int(machine.overlay_stack.back()).is_equal(GameStateMachine.OverlayKind.DEFEAT_PROMPT)
	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	var retried: BattleMode = root.current_mode_node() as BattleMode
	var rec: EncounterData = root.catalog().get_record(&"encounter", source.enc_id) as EncounterData
	assert_int(retried.battle.enemies.size()).is_equal(rec.enemy_ids.size())
	DebugLaunchArgs.force_outcome(retried.battle, DebugLaunchArgs.VICTORY)
	retried.settle_replay()
	assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_bool(root.world_state.is_resolved(_MAP_ID, source.symbol_id)).is_true()


## Leader onto the symbol with grace ended: one real frame of swept contact
## must start that symbol's record with the squad's own Combatants.
func _touch_and_enter_battle(root: GameRoot, ow: OverworldMode,
		source: EncounterSource) -> BattleMode:
	var party: Array = ow.party_source.call()
	ow.grace_active = false
	ow.set_leader_position(source.brain.position)
	ow.step_frame(_DT, Vector2.ZERO)
	assert_int(ow.get_state()).is_equal(OverworldMode.State.FROZEN)
	assert_bool(is_same(ow.pending_source, source)).is_true()
	_run_to_idle(root.machine)
	assert_int(root.machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	var battle_mode: BattleMode = root.current_mode_node() as BattleMode
	assert_object(battle_mode).is_not_null()
	var rec: EncounterData = root.catalog().get_record(&"encounter", source.enc_id) as EncounterData
	assert_int(battle_mode.battle.enemies.size()).is_equal(rec.enemy_ids.size())
	assert_int(battle_mode.battle.squad.size()).is_equal(party.size())
	for i: int in party.size():
		assert_bool(is_same(battle_mode.battle.squad[i], party[i])).is_true()
	return battle_mode


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = _DATA_ROOT
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _new_game(root: GameRoot) -> OverworldMode:
	assert_int(root.machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_int(root.machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	var ow: OverworldMode = root.current_mode_node() as OverworldMode
	ow.set_process(false)  # the test steps frames itself
	return ow


## Story 138: New Game in Town, then the real map change to the segment.
func _new_game_on_segment(root: GameRoot) -> OverworldMode:
	var town: OverworldMode = _new_game(root)
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(_MAP_ID, &"from_town"))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var ow: OverworldMode = root.current_mode_node() as OverworldMode
	assert_bool(is_same(ow, town)).is_false()
	ow.set_process(false)
	return ow


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks").is_true()
