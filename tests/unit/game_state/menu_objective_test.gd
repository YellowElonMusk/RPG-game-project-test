## GDD Overworld rule 19 "Objective line": the Menu's main screen shows the
## current chapter step's objective under its list; none when it has none.
extends GdUnitTestSuite


func _menu(objective: String) -> InterimMenu:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	var payload := MenuPayload.new()
	payload.entries = [&"pause", &"party", &"settings", &"quit"]
	var menu: InterimMenu = auto_free((load("res://src/game_state/overlays/interim_menu.tscn") as PackedScene).instantiate())
	menu.objective = objective
	menu.setup(machine, payload)
	add_child(menu)
	return menu


func _note_text(menu: InterimMenu) -> String:
	return (menu.get("_note") as Label).text


func test_main_screen_shows_the_objective() -> void:
	var menu := _menu("Find the CEO.")
	assert_str(_note_text(menu)).is_equal("Goal: Find the CEO.")


func test_no_objective_shows_no_goal_line() -> void:
	var menu := _menu("")
	assert_str(_note_text(menu)).is_empty()
