## GameRoot routes the Audio Manager (systems index #20): Title plays the
## title theme, New Game plays Paris Town's track and stage-1 bed, the
## overworld's sfx_cue reaches the SFX column, and menu clicks sound only
## while something other than free walking has the input.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DT: float = 1.0 / 60.0


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.tutorial_hints_enabled = false
	root.data_root_override = "res://data"
	root.save_dir_override = "user://test_saves_audio"
	root.settings_path_override = "user://test_game_root_audio.json"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1


func test_title_then_new_game_route_music_and_ambience() -> void:
	var root: GameRoot = _boot()
	assert_object(root.audio).is_not_null()
	assert_str(String(root.audio.current_music_id)).is_equal("mus_title")
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	assert_str(String(root.audio.current_music_id)).is_equal("mus_paris_town")
	assert_str(String(root.audio.current_ambience_id)).is_equal("amb_paris_stage1")


func test_overworld_cues_and_menu_clicks_reach_the_sfx_column() -> void:
	var root: GameRoot = _boot()
	root.resolver.action_pressed.emit(InputActions.NAV_DOWN)
	assert_array(root.audio.sfx_log).contains([AudioIds.UI_MOVE])
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	root.audio.sfx_log.clear()
	town.sfx_cue.emit(OverworldSfx.NOTICE, "symbol")
	assert_array(root.audio.sfx_log).is_equal([OverworldSfx.NOTICE])
	# Free walking: no UI click.
	root.audio.advance(1.0)
	root.resolver.action_pressed.emit(InputActions.NAV_DOWN)
	assert_array(root.audio.sfx_log).is_equal([OverworldSfx.NOTICE])
