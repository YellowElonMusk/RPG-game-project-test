## The Settings screen: rows step values through the service, left/right
## work on the focused row, Back flushes and closes, and Title and the Menu
## open it when a service is injected.
extends GdUnitTestSuite

var _fs: MemorySaveFileSystem


func before_test() -> void:
	_fs = MemorySaveFileSystem.new()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _service() -> SettingsService:
	var config := SettingsConfig.new()
	config.path = "user://test_panel_settings.json"
	var service: SettingsService = auto_free(SettingsService.new())
	service.setup(_fs, config, SettingsSchema.new(), func() -> float: return 0.0)
	return service


func _panel(service: SettingsService) -> SettingsPanel:
	var panel: SettingsPanel = auto_free(SettingsPanel.new())
	panel.setup(service)
	add_child(panel)
	return panel


func test_rows_show_current_values() -> void:
	var panel := _panel(_service())
	assert_str(panel.row(&"text_speed").text).is_equal("Text speed: Normal")
	assert_str(panel.row(&"master_volume").text).is_equal("Master volume: 80%")
	assert_str(panel.row(&"reduce_flashing").text).is_equal("Reduce flashing: Off")


func test_confirm_steps_an_enum_forward_and_wraps() -> void:
	var service := _service()
	var panel := _panel(service)
	panel.row(&"text_speed").pressed.emit()
	assert_str(service.get_value(&"text_speed")).is_equal("fast")
	panel.row(&"text_speed").pressed.emit()
	panel.row(&"text_speed").pressed.emit()
	assert_str(service.get_value(&"text_speed")).is_equal("slow")
	assert_str(panel.row(&"text_speed").text).is_equal("Text speed: Slow")


func test_left_right_step_the_focused_row_and_volumes_clamp() -> void:
	var service := _service()
	var panel := _panel(service)
	panel.row(&"master_volume").grab_focus()
	panel.handle_action(InputActions.NAV_RIGHT, true)
	panel.handle_action(InputActions.NAV_RIGHT, true)
	panel.handle_action(InputActions.NAV_RIGHT, true)
	assert_int(service.get_value(&"master_volume")).is_equal(100)
	panel.handle_action(InputActions.NAV_LEFT, true)
	assert_int(service.get_value(&"master_volume")).is_equal(90)


func test_bool_row_toggles() -> void:
	var service := _service()
	var panel := _panel(service)
	panel.row(&"reduce_motion").grab_focus()
	panel.handle_action(InputActions.CONFIRM, true)
	assert_bool(service.get_value(&"reduce_motion")).is_true()
	assert_str(panel.row(&"reduce_motion").text).is_equal("Reduce motion: On")


func test_back_and_cancel_flush_and_close() -> void:
	var service := _service()
	var panel := _panel(service)
	var closes: Array = [0]
	panel.closed.connect(func() -> void: closes[0] += 1)
	panel.row(&"screen_shake").pressed.emit()
	assert_bool(service.is_dirty()).is_true()
	panel.handle_action(InputActions.CANCEL, true)
	assert_bool(service.is_dirty()).is_false()
	assert_bool(_fs.files.has("user://test_panel_settings.json")).is_true()
	panel.back_button().pressed.emit()
	assert_int(closes[0]).is_equal(2)


func test_menu_settings_entry_opens_and_closes_the_panel() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(SequenceRecorder.new())
	var machine: GameStateMachine = env["machine"]
	var payload := MenuPayload.new()
	payload.entries = [&"pause", &"party", &"codex", &"settings", &"quit"]
	var menu: InterimMenu = auto_free((load("res://src/game_state/overlays/interim_menu.tscn") as PackedScene).instantiate())
	menu.settings_service = _service()
	menu.setup(machine, payload)
	add_child(menu)
	assert_bool(menu.button_for(&"settings").disabled).is_false()
	menu.button_for(&"settings").pressed.emit()
	assert_object(menu.settings_panel).is_not_null()
	# While open, actions go to the panel: cancel closes it, not the Menu.
	menu.handle_action(InputActions.CANCEL, true)
	assert_object(menu.settings_panel).is_null()
	assert_object(menu.button_for(&"settings")).is_not_null()


func test_title_settings_button_opens_the_panel() -> void:
	var title: TitleMode = auto_free((load("res://src/game_state/modes/title_mode.tscn") as PackedScene).instantiate())
	title.settings_service = _service()
	title.setup(null, null)
	add_child(title)
	var button: Button = title.get_node("%SettingsButton")
	assert_bool(button.disabled).is_false()
	button.pressed.emit()
	assert_object(title.settings_panel).is_not_null()
	title.handle_action(InputActions.CANCEL, true)
	assert_object(title.settings_panel).is_null()


func test_title_without_a_service_keeps_settings_disabled() -> void:
	var title: TitleMode = auto_free((load("res://src/game_state/modes/title_mode.tscn") as PackedScene).instantiate())
	title.setup(null, null)
	add_child(title)
	assert_bool((title.get_node("%SettingsButton") as Button).disabled).is_true()
