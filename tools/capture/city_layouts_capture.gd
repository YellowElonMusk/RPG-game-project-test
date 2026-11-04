extends SceneTree
## City layouts evidence: boots `GameRoot`, starts a New Game, ends each
## chapter through GameRoot's real chapter-end handler, and saves the town
## and the dungeon of London, Sydney and New York (their own layouts,
## `tools/maps/city_layouts.py`), then the New York café's shop with its
## local stock. Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/city_layouts_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/city-layouts/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://city_layouts_capture_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200
## [chapter-end step of the previous chapter, city, chapter id]
const CITIES: Array = [
	["step_walk_home_b", "london", "chapter_london"],
	["london_step_walk_home_b", "sydney", "chapter_sydney"],
	["sydney_step_walk_home_b", "newyork", "chapter_newyork"],
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
	_root_node.tutorial_hints_enabled = false  # no onboarding cards in this evidence
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
	var n: int = 1
	for city: Array in CITIES:
		_root_node.world_state.chapter_step = city[0]
		_root_node._on_chapter_end_requested(_root_node.current_mode_node() as OverworldMode)
		await _frames(5)
		await _wait_mode(GameStateMachine.Mode.OVERWORLD)
		await _frames(20)
		await _close_dialogues()
		ok = _check("chapter is %s" % city[2], _root_node.world_state.chapter_id == city[2]) and ok
		await _frames(30)
		await _shot("%02d-%s-town" % [n, city[1]])
		n += 1
		ok = await _enter(["map_%s_dungeon_placeholder" % city[1], &"from_segment"]) and ok
		await _shot("%02d-%s-dungeon" % [n, city[1]])
		n += 1
	var ws: WorldState = _root_node.world_state
	ws.money = 300
	var camp_payload := CampEntryPayload.new()
	camp_payload.camp_id = "camp_newyork_cafe"
	ok = _check("camp request", m.request_transition(GameStateMachine.Mode.CAMP, camp_payload) == GameStateMachine.RequestResult.OK) and ok
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.CAMP)
	await _frames(20)
	var camp: InterimCampMode = _root_node.current_mode_node() as InterimCampMode
	ok = _check("camp has a shop", camp != null and camp.rows().has(InterimCampMode.SHOP)) and ok
	if camp != null:
		camp.handle_action(InputActions.NAV_DOWN, true)
		camp.handle_action(InputActions.CONFIRM, true)  # Shop
		camp.handle_action(InputActions.CONFIRM, true)  # street pretzel
		await _frames(5)
		ok = _check("bought a street pretzel", ws.inventory.count("item_street_pretzel") == 1) and ok
		await _frames(20)
		await _shot("%02d-newyork-cafe-shop" % n)
	_finish(ok)


func _finish(ok: bool) -> void:
	print("city_layouts_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _enter(stop: Array) -> bool:
	var m: GameStateMachine = _root_node.machine
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(stop[0], stop[1]))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(30)
	return _check("enter %s" % stop[0], res == GameStateMachine.RequestResult.OK)


func _check(label: String, cond: bool) -> bool:
	print("city_layouts_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
