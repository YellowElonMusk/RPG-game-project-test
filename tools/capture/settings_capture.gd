extends SceneTree
## Settings screen evidence: boots `GameRoot`, opens Settings from Title
## (steps a couple of rows so changed values show), then starts a New Game
## and opens Settings from the overworld Menu. Points the settings file at
## its own path so the player's real settings are untouched. Needs a window
## and a GPU:
##
##   godot --path . -s res://tools/capture/settings_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/settings/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://settings_capture_saves"
const SETTINGS_PATH: String = "user://settings_capture.json"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200

var _root_node: GameRoot = null
var _out: String = DEFAULT_OUT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	_root_node = (load(GAME_ROOT_SCENE) as PackedScene).instantiate() as GameRoot
	_root_node.save_dir_override = SAVE_DIR
	_root_node.settings_path_override = SETTINGS_PATH
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine
	if m._action_source != null:
		m._unbind_action_source()
	var ok: bool = true
	await _wait_mode(GameStateMachine.Mode.TITLE)
	var title: TitleMode = _root_node.current_mode_node() as TitleMode
	(title.get_node("%SettingsButton") as Button).pressed.emit()
	await _frames(4)
	var panel: SettingsPanel = title.settings_panel
	ok = _check("title settings open", panel != null) and ok
	if panel == null:
		quit(1)
		return
	panel.step(&"text_speed", 1)
	panel.step(&"music_volume", -1)
	panel.row(&"text_speed").grab_focus()
	await _frames(6)
	ok = _check("text speed now fast", _root_node.settings_service.get_value(&"text_speed") == "fast") and ok
	await _shot("01-settings-from-title")
	panel.handle_action(InputActions.CANCEL, true)
	await _frames(4)
	ok = _check("file written on Back", FileAccess.file_exists(SETTINGS_PATH)) and ok
	title._on_new_game_pressed()
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	m.open_overlay(GameStateMachine.OverlayKind.MENU, m._build_menu_payload())
	await _frames(4)
	var menu: InterimMenu = _root_node.current_overlay_node() as InterimMenu
	ok = _check("menu open", menu != null) and ok
	if menu == null:
		quit(1)
		return
	ok = _check("menu settings enabled", not menu.button_for(&"settings").disabled) and ok
	await _shot("02-menu-with-settings")
	menu.button_for(&"settings").pressed.emit()
	await _frames(6)
	ok = _check("menu settings open", menu.settings_panel != null) and ok
	await _shot("03-settings-from-menu")
	print("settings_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("settings_capture: %s %s" % [label, "ok" if cond else "FAILED"])
	return cond


func _shot(name: String) -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _wait_mode(mode: GameStateMachine.Mode) -> void:
	var m: GameStateMachine = _root_node.machine
	var n: int = 0
	while not (m.phase == GameStateMachine.Phase.IDLE and m.current_mode == mode) and n < WAIT_CAP:
		await process_frame
		n += 1


func _close_dialogues() -> void:
	var m: GameStateMachine = _root_node.machine
	var guard: int = 0
	while GameStateMachine.OverlayKind.DIALOGUE in m.overlay_stack and guard < 20:
		var line: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.skip_to_end()
		await _frames(4)
		guard += 1
