extends SceneTree
## The Menu overlay in the real game (the Menu soft-lock fix): boots
## `GameRoot`, starts a New Game, presses the menu key through the machine's
## real input path in the Overworld, then again in a Battle, and saves
## `overworld_menu.png`, `overworld_after_close.png` and `battle_menu.png`.
## Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/menu_overlay_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/menu-overlay/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://menu_capture_saves"
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
	_root_node = (load(GAME_ROOT_SCENE) as PackedScene).instantiate() as GameRoot
	_root_node.save_dir_override = SAVE_DIR
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine
	if m._action_source != null:
		m._unbind_action_source()
	var ok: bool = true
	await _wait_mode(GameStateMachine.Mode.TITLE)
	(_root_node.current_mode_node() as TitleMode)._on_new_game_pressed()
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(20)
	m._on_source_action_pressed(&"menu")
	await _frames(10)
	ok = _check("overworld open", m.overlay_stack == [GameStateMachine.OverlayKind.MENU]) and ok
	ok = _check("overworld menu node", _root_node.current_overlay_node() is InterimMenu) and ok
	await _shot("overworld_menu")
	m._on_source_action_pressed(&"menu")
	await _frames(10)
	ok = _check("overworld closed by the menu key", m.overlay_stack.is_empty()) and ok
	await _shot("overworld_after_close")
	var rec: EncounterData = _root_node.catalog().get_record(&"encounter", "enc_paris_clerks_hall") as EncounterData
	var payload := BattleEntryPayload.new()
	payload.descriptor = OverworldMode.build_descriptor(rec)
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	if ow != null and ow.party_source.is_valid():
		payload.party.assign(ow.party_source.call())
	ok = _check("battle request", m.request_transition(GameStateMachine.Mode.BATTLE, payload) == GameStateMachine.RequestResult.OK) and ok
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	await _frames(90)
	m._on_source_action_pressed(&"menu")
	await _frames(10)
	ok = _check("battle open", m.overlay_stack == [GameStateMachine.OverlayKind.MENU]) and ok
	await _shot("battle_menu")
	var menu: InterimMenu = _root_node.current_overlay_node() as InterimMenu
	if menu != null:
		menu.handle_action(InputActions.CANCEL, true)
	await _frames(5)
	ok = _check("battle closed by cancel", m.overlay_stack.is_empty()) and ok
	print("menu_overlay_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("menu_overlay_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
		await _frames(4)
		var line: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.advance_guard(1.0)
			line.handle_action(InputActions.CONFIRM, true)
			line.handle_action(InputActions.CONFIRM, false)
		await _frames(4)
		guard += 1
