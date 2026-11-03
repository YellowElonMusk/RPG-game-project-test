extends SceneTree
## The overworld's stand-in look in the real game: boots `GameRoot`, starts a
## New Game, and saves one frame per Paris map (town, segment, dungeon, boss
## chamber), each entered through the real map-change path. Needs a window
## and a GPU:
##
##   godot --path . -s res://tools/capture/overworld_look_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/overworld-look/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://overworld_look_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200
## map id -> the entry marker the capture enters it at.
const STOPS: Array = [
	["map_paris_segment_placeholder", &"from_town"],
	["map_paris_dungeon_placeholder", &"from_segment"],
	["map_paris_boss_chamber_placeholder", &"from_dungeon"],
]

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
	await _frames(30)
	await _shot("01-town")
	var n: int = 2
	for stop: Array in STOPS:
		var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD,
				MapEntryPayload.new(stop[0], stop[1]))
		ok = _check("enter %s" % stop[0], res == GameStateMachine.RequestResult.OK) and ok
		await _frames(5)
		await _wait_mode(GameStateMachine.Mode.OVERWORLD)
		await _close_dialogues()
		await _frames(30)
		await _shot("%02d-%s" % [n, String(stop[0]).trim_prefix("map_paris_").trim_suffix("_placeholder")])
		n += 1
	print("overworld_look_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("overworld_look_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
