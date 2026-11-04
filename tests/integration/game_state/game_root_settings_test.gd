## GameRoot builds the SettingsService first, reads the settings file at
## boot, and hands each consumer its view: Title gets the service for its
## Settings screen, and the Reduce Flashing view the FlashGate reads follows
## the service live.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _PATH: String = "user://test_game_root_settings.json"
const _DT: float = 1.0 / 60.0


func after_test() -> void:
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(_PATH)


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = "user://test_saves_settings"
	root.settings_path_override = _PATH
	add_child(root)
	auto_free(root)
	var ticks: int = 0
	while root.machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		root.machine.tick(_DT)
		ticks += 1
	return root


func test_boot_reads_the_settings_file_and_title_gets_the_service() -> void:
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": SettingsService.FORMAT, "version": 1,
			"body": {"text_speed": "slow"}}))
	f.close()
	var root: GameRoot = _boot()
	assert_object(root.settings_service).is_not_null()
	assert_str(root.settings_service.get_value(&"text_speed")).is_equal("slow")
	var title: TitleMode = root.current_mode_node() as TitleMode
	assert_object(title).is_not_null()
	assert_object(title.settings_service).is_same(root.settings_service)
	assert_bool((title.get_node("%SettingsButton") as Button).disabled).is_false()


func test_flash_gate_reads_reduce_flashing_live() -> void:
	var root: GameRoot = _boot()
	var gate: FlashGate = root.get_node("%Services/FlashGate") as FlashGate
	assert_object(gate).is_not_null()
	var settings: FlashSettings = gate.get("_settings") as FlashSettings
	assert_bool(settings.reduce_flashing()).is_false()
	root.settings_service.set_value(&"reduce_flashing", true)
	assert_bool(settings.reduce_flashing()).is_true()
