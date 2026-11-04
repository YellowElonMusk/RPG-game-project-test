extends SceneTree
## Rat Catchers evidence (narrative bible §6.5): boots `GameRoot`, starts a
## New Game, ends Paris through GameRoot's real chapter-end handler, gives
## the squad alien points and saves the London street ambush's conversation
## and its battle. With `--captain`, the walk home instead: the Captain's
## battle (a battle cannot hand back to the Overworld directly). Needs a
## window and a GPU:
##
##   godot --path . -s res://tools/capture/rat_catchers_capture.gd [-- --out=res://dir/]
##   godot --path . -s res://tools/capture/rat_catchers_capture.gd -- --captain

const DEFAULT_OUT: String = "res://production/qa/evidence/rat-catchers/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://rat_catchers_capture_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200
const SEGMENT: String = "map_london_segment_placeholder"

var _root_node: GameRoot = null
var _out: String = DEFAULT_OUT
var _captain: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--captain":
			_captain = true
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
	_root_node.world_state.chapter_step = "step_walk_home_b"
	_root_node._on_chapter_end_requested(_root_node.current_mode_node() as OverworldMode)
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	ok = _check("chapter is london", _root_node.world_state.chapter_id == "chapter_london") and ok
	if _captain:
		_root_node.world_state.alien_points = 1
		_root_node.world_state.set_flag("london_liberated")
		ok = await _enter(&"from_dungeon") and ok
		var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
		ok = _check("captain due", ow.rat_catcher_encounter == "enc_rat_captain_london") and ok
		# The Commuter's join line, then the Captain's conversation, then the fight.
		await _close_dialogues()
		await _wait_mode(GameStateMachine.Mode.BATTLE)
		ok = _check("captain battle", m.current_mode == GameStateMachine.Mode.BATTLE) and ok
		await _frames(150)
		await _shot("03-rat-captain-battle")
		_finish(ok)
		return
	_root_node.world_state.alien_points = 2
	ok = await _enter(&"from_town") and ok
	var seg: OverworldMode = _root_node.current_mode_node() as OverworldMode
	# The shipped chance at 2 alien points is 50%: force this visit's roll.
	var cfg: RatCatcherConfig = RatCatcherConfig.load_default().duplicate() as RatCatcherConfig
	cfg.ambush_base_chance = 1.0
	cfg.ambush_max_chance = 1.0
	seg.rat_catcher_config = cfg
	if seg.rat_catcher_encounter.is_empty():
		seg._roll_rat_catchers()
	ok = _check("ambush due", seg.rat_catcher_encounter == "enc_rat_ambush_london") and ok
	await _frames(150)
	await _shot("01-ambush-conversation")
	await _close_dialogues()
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	var battle_mode := _root_node.current_mode_node() as BattleMode
	ok = _check("ambush battle", battle_mode != null and battle_mode.battle.faction_rule is RatCatchersRule) and ok
	await _frames(150)
	await _shot("02-ambush-battle")
	_finish(ok)


func _finish(ok: bool) -> void:
	print("rat_catchers_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _enter(entry: StringName) -> bool:
	var m: GameStateMachine = _root_node.machine
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(SEGMENT, entry))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _frames(30)
	return _check("enter %s" % entry, res == GameStateMachine.RequestResult.OK)


func _check(label: String, cond: bool) -> bool:
	print("rat_catchers_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
