## Regression: the Menu overlay had no scene. Focus loss or the menu key
## pushed a MENU entry with no node behind it, so mode time froze, every press
## was dropped (no overlay node to receive it) and a second menu press stacked
## another empty MENU: a soft-lock from one alt-tab. Now a failed overlay load
## rolls its entry back, the menu key closes an open Menu, and the shipped
## config maps MENU to a real scene.
extends GdUnitTestSuite

const _MENU_ACTION: StringName = &"menu"


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func test_failed_overlay_load_leaves_no_stack_entry_and_time_running() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	loader.push_overlay_result = false

	var result: GameStateMachine.RequestResult = machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())

	assert_int(result).is_not_equal(GameStateMachine.RequestResult.OK)
	assert_array(machine.overlay_stack).override_failure_message(
			"a MENU entry with no node behind it was left on the stack").is_empty()
	assert_bool(loader.set_mode_time_stopped_calls.has(true)).override_failure_message(
			"mode time stopped for a Menu that never appeared").is_false()


func test_menu_key_on_an_open_menu_closes_it() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	source.press(_MENU_ACTION)
	assert_int(machine.overlay_stack.size()).is_equal(1)
	source.press(_MENU_ACTION)

	assert_array(machine.overlay_stack).override_failure_message(
			"a second menu press stacked another Menu").is_empty()


func test_shipped_config_maps_the_menu_to_a_game_overlay_scene() -> void:
	var config: TransitionConfig = load("res://data/config/transition_config.tres") as TransitionConfig
	var path: String = String(config.overlay_scene_paths.get(GameStateMachine.OverlayKind.MENU, ""))
	assert_str(path).override_failure_message("no Menu scene: the Menu soft-locks the game").is_not_empty()
	var node: Node = auto_free((load(path) as PackedScene).instantiate())
	assert_object(node as GameOverlay).is_not_null()


func test_menu_renders_exactly_the_payload_entries_and_resume_closes() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())
	var payload := MenuPayload.new()
	payload.entries = [&"pause", &"party", &"codex", &"settings", &"quit"]
	var menu: InterimMenu = auto_free((load("res://src/game_state/overlays/interim_menu.tscn") as PackedScene).instantiate())
	menu.setup(machine, payload)
	add_child(menu)

	assert_array(menu.entries()).is_equal(payload.entries)
	assert_bool(menu.button_for(&"pause").disabled).is_false()
	assert_bool(menu.button_for(&"settings").disabled).is_true()
	assert_bool(menu.button_for(&"quit").disabled).is_false()
	menu.button_for(&"pause").pressed.emit()
	assert_array(machine.overlay_stack).override_failure_message("Resume did not close the Menu").is_empty()


func test_cancel_closes_the_menu() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())
	var menu: InterimMenu = auto_free((load("res://src/game_state/overlays/interim_menu.tscn") as PackedScene).instantiate())
	menu.setup(machine, null)

	assert_bool(menu.handle_action(InputActions.CANCEL, true)).is_true()
	assert_array(machine.overlay_stack).is_empty()


## The Battle Menu's payload is only settings and quit (AC-31); with no
## Resume, focus landed on Quit to Title and a stray Confirm left the fight.
func test_battle_menu_opens_focused_on_resume_not_quit() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	var payload := MenuPayload.new()
	payload.entries = [&"settings", &"quit"]
	var menu: InterimMenu = auto_free((load("res://src/game_state/overlays/interim_menu.tscn") as PackedScene).instantiate())
	menu.setup(machine, payload)
	add_child(menu)

	assert_array(menu.entries()).is_equal(payload.entries)
	var resume: Button = menu.button_for(&"pause")
	assert_object(resume).override_failure_message("no Resume in the Battle Menu").is_not_null()
	assert_object(menu.get_viewport().gui_get_focus_owner()).override_failure_message(
			"the Battle Menu did not open on Resume").is_same(resume)
