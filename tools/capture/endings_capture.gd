extends SceneTree
## Faction Reputation & Endings evidence: boots `GameRoot`, and for each
## ending sets the squad's reputation, plays the campaign end in Paris and
## saves the ending conversation's first line. The human run carries on to
## Title and saves the credits mid-roll. Also saves the Party screen with
## the reputation line. Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/endings_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/endings/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://endings_capture_saves"
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
	_root_node.tutorial_hints_enabled = false  # no onboarding cards in this evidence
	_root_node.save_dir_override = SAVE_DIR
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine
	if m._action_source != null:
		m._unbind_action_source()
	var ok: bool = true
	await _wait_mode(GameStateMachine.Mode.TITLE)
	# [cred, alien, file, expected ending]
	var runs: Array = [
		[0, 2, "02-ending-alien-first-line", EndingRules.ALIEN],
		[1, 1, "03-ending-split-first-line", EndingRules.SPLIT],
		[2, 1, "01-ending-human-first-line", EndingRules.HUMAN],
	]
	for run: Array in runs:
		var title: TitleMode = _root_node.current_mode_node() as TitleMode
		if title.credits_panel != null:
			title._on_credits_finished()
		title._on_new_game_pressed()
		await _wait_mode(GameStateMachine.Mode.OVERWORLD)
		await _close_dialogues()
		var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
		_root_node.world_state.street_cred = run[0]
		_root_node.world_state.alien_points = run[1]
		if run[3] == EndingRules.HUMAN:
			_open_party(m)
			await _frames(8)
			await _shot("05-party-reputation-line")
			m.close_overlay()
			await _frames(2)
		var only_paris := Campaign.new()
		only_paris.chapters.append(Campaign.load_default().chapters[0])
		_root_node.campaign = only_paris
		_root_node.world_state.chapter_step = "step_walk_home_b"
		_root_node._on_chapter_end_requested(ow)
		await _frames(2)
		var box: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
		ok = _check("%s conversation open" % run[3], box != null) and ok
		ok = _check("%s picked" % run[3], _root_node.ending != null and _root_node.ending.id == run[3]) and ok
		if box == null:
			quit(1)
			return
		box.reveal_all()
		await _frames(6)
		await _shot(run[2])
		await _close_dialogues()
		await _wait_mode(GameStateMachine.Mode.TITLE)
		var t: TitleMode = _root_node.current_mode_node() as TitleMode
		ok = _check("%s credits rolling" % run[3], t.credits_panel != null) and ok
		if run[3] == EndingRules.HUMAN and t.credits_panel != null:
			await _frames(30)
			await _shot("04-credits-start")
			t.credits_panel.advance(9.0)
			await _frames(4)
			await _shot("04b-credits-mid-roll")
	print("endings_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _open_party(m: GameStateMachine) -> void:
	m.open_overlay(GameStateMachine.OverlayKind.MENU, m._build_menu_payload())
	var menu: InterimMenu = _root_node.current_overlay_node() as InterimMenu
	if menu != null:
		menu._show_party()


func _check(label: String, cond: bool) -> bool:
	print("endings_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
