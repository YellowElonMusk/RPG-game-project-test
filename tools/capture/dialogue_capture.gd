extends SceneTree
## Dialogue system evidence: boots `GameRoot`, starts a New Game, goes to
## the Paris segment, walks up to the café regular and talks to them with
## a real `confirm`. Saves the line mid-reveal, the whole line, the choice
## list, and the squad banter line that follows the first choice. Needs a
## window and a GPU:
##
##   godot --path . -s res://tools/capture/dialogue_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/dialogue/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://dialogue_capture_saves"
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
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_paris_segment_placeholder", &"from_town"))
	ok = _check("enter segment", res == GameStateMachine.RequestResult.OK) and ok
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	var npc: NpcSpawn = null
	for n: NpcSpawn in ow.get_map().npc_spawns():
		if n.marker_id == &"npc_union_regular":
			npc = n
	ok = _check("found the café regular", npc != null) and ok
	if npc == null:
		quit(1)
		return
	ow.grace_active = false
	var at: Vector2 = npc.ground_position(ow.get_map())
	ow.set_leader_position(at + Vector2(0.0, 0.9))
	await _frames(40)
	await _close_dialogues()
	ow.confirm()
	await _frames(2)
	var box: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
	if box == null:
		# Not in reach from that side: talk to them directly instead.
		_check("confirm reached the NPC", false)
		ow.talk(Conversation.load_by_id(npc.conversation_id))
		await _frames(2)
		box = _root_node.current_overlay_node() as InterimLineDialogue
	ok = _check("conversation open", box != null) and ok
	if box == null:
		quit(1)
		return
	await _frames(12)
	await _shot("01-line-revealing")
	box.reveal_all()
	await _frames(6)
	await _shot("02-line-whole")
	box.advance_guard(1.0)
	box.handle_action(InputActions.CONFIRM, true)
	box.reveal_all()
	await _frames(6)
	ok = _check("choices shown", box.choice_labels().size() == 2) and ok
	await _shot("03-choice")
	box.advance_guard(1.0)
	box.handle_action(InputActions.NAV_DOWN, true)
	box.handle_action(InputActions.NAV_UP, true)
	box.handle_action(InputActions.CONFIRM, true)
	box.reveal_all()
	box.advance_guard(1.0)
	box.handle_action(InputActions.CONFIRM, true)
	box.reveal_all()
	await _frames(6)
	ok = _check("karen banter", box.text.begins_with("Karen:")) and ok
	ok = _check("tip flag set", _root_node.world_state.has_flag("paris_heard_union_tip")) and ok
	await _shot("04-squad-banter")
	print("dialogue_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("dialogue_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
