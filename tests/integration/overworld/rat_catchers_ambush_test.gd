## The Rat Catchers through a real GameRoot (narrative bible §6.5): on a
## street segment with alien points, their conversation opens, then their
## fight (no alien rule), and a Victory brings back their parting line. On
## the walk home the Captain comes once per chapter; at 0 alien points
## nobody comes.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_rat_catchers"
const _SEGMENT: String = "map_london_segment_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_an_ambush_talks_then_fights_then_gives_up() -> void:
	var root: GameRoot = _new_game()
	root.world_state.chapter_id = "chapter_london"
	root.world_state.alien_points = 2
	var seg: OverworldMode = _go(root, _SEGMENT, &"from_town")
	_close_overlays(root)
	# Force the roll (the shipped chance at 2 points is 50%).
	var cfg: RatCatcherConfig = RatCatcherConfig.load_default().duplicate() as RatCatcherConfig
	cfg.ambush_base_chance = 1.0
	cfg.ambush_max_chance = 1.0
	seg.rat_catcher_config = cfg
	seg._roll_rat_catchers()
	assert_str(seg.rat_catcher_encounter).is_equal("enc_rat_ambush_london")

	seg.step_frame(_DT, Vector2.ZERO)
	var talk: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_object(talk).override_failure_message("no ambush conversation").is_not_null()
	assert_str(seg.lines_said.back()).contains("Rats")
	talk.advance_guard(0.2)
	talk.skip_to_end()
	_run_to_idle(root.machine)

	seg.step_frame(_DT, Vector2.ZERO)
	_run_to_idle(root.machine)
	var battle: BattleMode = root.current_mode_node() as BattleMode
	assert_object(battle).override_failure_message("no Rat Catcher fight").is_not_null()
	assert_object(battle.battle.faction_rule).is_instanceof(RatCatchersRule)
	assert_int(seg.rat_catcher_starts).is_equal(1)
	assert_int(RatCatchers.ambushes_met(root.world_state, _SEGMENT, cfg)).is_equal(1)

	DebugLaunchArgs.force_outcome(battle.battle, DebugLaunchArgs.VICTORY)
	battle.settle_replay()
	assert_int(root.machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_object(line).override_failure_message("no parting line").is_not_null()
	assert_str(seg.lines_said.back()).contains("not rats")


func test_no_rat_catchers_at_zero_alien_points() -> void:
	var root: GameRoot = _new_game()
	root.world_state.chapter_id = "chapter_london"
	var seg: OverworldMode = _go(root, _SEGMENT, &"from_town")
	assert_str(seg.rat_catcher_encounter).is_empty()
	# Not on the walk home either.
	root.world_state.set_flag("london_liberated")
	var home: OverworldMode = _go(root, _SEGMENT, &"from_dungeon")
	assert_str(home.rat_catcher_encounter).is_empty()


func test_the_captain_waits_on_the_walk_home_once() -> void:
	var root: GameRoot = _new_game()
	root.world_state.chapter_id = "chapter_london"
	root.world_state.alien_points = 1
	root.world_state.set_flag("london_liberated")
	var home: OverworldMode = _go(root, _SEGMENT, &"from_dungeon")
	assert_str(home.rat_catcher_encounter).is_equal("enc_rat_captain_london")
	_close_overlays(root)  # a recruit's join line goes first
	home.step_frame(_DT, Vector2.ZERO)
	assert_str(home.lines_said.back()).contains("Wanted")
	(root.current_overlay_node() as InterimLineDialogue).advance_guard(0.2)
	(root.current_overlay_node() as InterimLineDialogue).skip_to_end()
	_run_to_idle(root.machine)
	home.step_frame(_DT, Vector2.ZERO)
	_run_to_idle(root.machine)
	var battle: BattleMode = root.current_mode_node() as BattleMode
	assert_object(battle).is_not_null()
	assert_bool(root.world_state.has_flag("rat_captain_met_london")).is_true()
	# Back on the segment later in the chapter: no second Captain.
	DebugLaunchArgs.force_outcome(battle.battle, DebugLaunchArgs.VICTORY)
	battle.settle_replay()
	assert_int(root.machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var again: OverworldMode = _go(root, _SEGMENT, &"from_dungeon")
	assert_str(again.rat_catcher_encounter).is_empty()


func _close_overlays(root: GameRoot) -> void:
	var guard: int = 0
	while not root.machine.overlay_stack.is_empty() and guard < 10:
		var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.advance_guard(0.2)
			line.skip_to_end()
		else:
			root.machine.close_overlay()
		_run_to_idle(root.machine)
		guard += 1


func _new_game() -> GameRoot:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	(root.current_mode_node() as OverworldMode).set_process(false)
	return root


func _go(root: GameRoot, map_id: String, entry: StringName) -> OverworldMode:
	_close_overlays(root)
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(map_id, entry))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var mode: OverworldMode = root.current_mode_node() as OverworldMode
	mode.set_process(false)
	return mode


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.tutorial_hints_enabled = false  # onboarding cards would gate round 1
	root.data_root_override = "res://data"
	root.save_dir_override = _SAVE_DIR
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message("transition did not finish").is_true()


func _clear_saves() -> void:
	var dir := DirAccess.open(_SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
