extends SceneTree
## Chapter 4 evidence: boots `GameRoot`, starts a New Game, ends Paris,
## London and Sydney through GameRoot's real chapter-end handler, and saves
## one frame per New York map (the arrival line, Times Square, Fifth Avenue,
## the Liberty Dome, the Fifty-Star Stage), a Liberty-7 street fight after
## one round of Attacks (the command menu refuses a second Attack), and the
## Super Patriot boss battle (a second run with `--boss`: a battle cannot hand back to the
## Overworld directly). Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/chapter4_usa_capture.gd [-- --out=res://dir/]
##   godot --path . -s res://tools/capture/chapter4_usa_capture.gd -- --boss

const DEFAULT_OUT: String = "res://production/qa/evidence/chapter4-usa/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://chapter4_capture_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200
const DT: float = 1.0 / 60.0
const SEGMENT: Array = ["map_newyork_segment_placeholder", &"from_town"]
const STOPS: Array = [
	["map_newyork_dungeon_placeholder", &"from_segment"],
	["map_newyork_boss_chamber_placeholder", &"from_dungeon"],
]

var _root_node: GameRoot = null
var _out: String = DEFAULT_OUT
var _boss_only: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--boss":
			_boss_only = true
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
	for step: String in ["step_walk_home_b", "london_step_walk_home_b", "sydney_step_walk_home_b"]:
		_root_node.world_state.chapter_step = step
		_root_node._on_chapter_end_requested(_root_node.current_mode_node() as OverworldMode)
		await _frames(5)
		await _wait_mode(GameStateMachine.Mode.OVERWORLD)
		await _frames(20)
		if step != "sydney_step_walk_home_b":
			await _close_dialogues()
	ok = _check("chapter is new york", _root_node.world_state.chapter_id == "chapter_newyork") and ok
	if _boss_only:
		await _close_dialogues()
		ok = await _enter(STOPS[1]) and ok
		ok = await _walk_into_first_symbol() and ok
		await _frames(120)
		await _shot("07-super-patriot-battle")
		_finish(ok)
		return
	await _frames(240)
	await _shot("01-arrival-line")
	await _close_dialogues()
	await _frames(30)
	await _shot("02-town")
	ok = await _enter(SEGMENT) and ok
	await _shot("03-segment")
	var n: int = 4
	for stop: Array in STOPS:
		ok = await _enter(stop) and ok
		await _shot("%02d-%s" % [n, String(stop[0]).trim_prefix("map_newyork_").trim_suffix("_placeholder")])
		n += 1
	# A street fight on Fifth Avenue: walk into the first symbol, then one
	# round of Attacks, so round 2 opens with Attack refused for the leader.
	ok = await _enter(SEGMENT) and ok
	ok = await _walk_into_first_symbol() and ok
	var battle_mode := _root_node.current_mode_node() as BattleMode
	ok = _check("street battle", battle_mode != null) and ok
	if battle_mode != null:
		await _frames(90)
		var core: BattleCore = battle_mode.battle
		ok = _check("liberty7 rule", core.faction_rule is Liberty7Rule) and ok
		var i: int = 0
		while core.round_number == 1 and core.state == BattleCore.State.SQUAD_TURN and i < 8:
			core.submit_action(Move.make_attack(), core.get_living_enemies()[0])
			i += 1
		battle_mode.settle_replay()
		await _frames(60)
		var actor: Combatant = core.get_active_combatant()
		ok = _check("attack refused for %s" % (actor.display_name if actor != null else "nobody"),
				actor != null and not core.faction_rule.move_allowed(actor, Move.make_attack())) and ok
		await _shot("06-liberty7-battle-no-repeat")
	_finish(ok)


func _finish(ok: bool) -> void:
	print("chapter4_usa_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _enter(stop: Array) -> bool:
	var m: GameStateMachine = _root_node.machine
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(stop[0], stop[1]))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(30)
	return _check("enter %s" % stop[0], res == GameStateMachine.RequestResult.OK)


func _walk_into_first_symbol() -> bool:
	var m: GameStateMachine = _root_node.machine
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	ow.set_process(false)
	var source: EncounterSource = ow.get_encounter_sources()[0]
	ow.grace_active = false
	ow.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	var guard: int = 0
	while m.phase == GameStateMachine.Phase.IDLE and guard < 120:
		ow.step_frame(DT, Vector2.UP)
		await process_frame
		guard += 1
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	return _check("battle started", m.current_mode == GameStateMachine.Mode.BATTLE)


func _check(label: String, cond: bool) -> bool:
	print("chapter4_usa_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
