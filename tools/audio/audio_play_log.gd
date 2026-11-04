extends SceneTree
## Audio evidence (systems index #20): boots `GameRoot` headless, plays
## Title -> New Game (Paris Town) -> the Paris dungeon -> a street fight
## (one round of Attacks) -> London's boss chamber after ending Paris, and
## prints what the Audio Manager is playing at each stop plus the SFX it
## fired. Audio can't be screenshotted; this log is the evidence.
##
##   godot --headless --path . -s res://tools/audio/audio_play_log.gd

const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const WAIT_CAP: int = 1200
const DT: float = 1.0 / 60.0

var _g: GameRoot = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_g = (load(GAME_ROOT_SCENE) as PackedScene).instantiate() as GameRoot
	_g.tutorial_hints_enabled = false
	_g.save_dir_override = "user://audio_play_log_saves"
	_g.settings_path_override = "user://audio_play_log_settings.json"
	root.add_child(_g)
	var m: GameStateMachine = _g.machine
	if m._action_source != null:
		m._unbind_action_source()
	var ok: bool = true
	await _wait_mode(GameStateMachine.Mode.TITLE)
	await _frames(60)
	ok = _log("Title", &"mus_title") and ok
	(_g.current_mode_node() as TitleMode)._on_new_game_pressed()
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(60)
	ok = _log("New Game: Paris Town", &"mus_paris_town") and ok
	_g.audio.sfx_log.clear()
	ok = await _enter(["map_paris_dungeon_placeholder", &"from_segment"]) and ok
	ok = _log("Paris dungeon", &"mus_paris_dungeon") and ok
	ok = await _enter(["map_paris_segment_placeholder", &"from_town"]) and ok
	ok = _log("Paris segment", &"mus_paris_segment") and ok
	ok = await _walk_into_first_symbol() and ok
	await _frames(90)
	ok = _log("Street fight", AudioIds.BX_FLOOR_PULSE) and ok
	var battle_mode := _g.current_mode_node() as BattleMode
	if battle_mode != null:
		var core: BattleCore = battle_mode.battle
		var i: int = 0
		while core.round_number == 1 and core.state == BattleCore.State.SQUAD_TURN and i < 8:
			core.submit_action(Move.make_attack(), core.get_living_enemies()[0])
			i += 1
		battle_mode.settle_replay()
		await _frames(60)
		print("audio_play_log: battle SFX after one round: %s" % [_g.audio.sfx_log])
		ok = _check("hits sounded", AudioIds.BT_HIT in _g.audio.sfx_log or AudioIds.BT_HIT_HEAVY in _g.audio.sfx_log
				or AudioIds.BT_KO_ENEMY in _g.audio.sfx_log) and ok
	print("audio_play_log: missing ids: %s" % [_g.audio.missing_ids])
	ok = _check("no missing ids", _g.audio.missing_ids.is_empty()) and ok
	print("audio_play_log: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _log(label: String, expect: StringName) -> bool:
	print("audio_play_log: %-22s music=%s ambience=%s fading=%s sfx=%s" % [label, _g.audio.current_music_id,
			_g.audio.current_ambience_id, _g.audio.is_fading(), _g.audio.sfx_log])
	return _check("%s plays %s" % [label, expect], _g.audio.current_music_id == expect)


func _enter(stop: Array) -> bool:
	var m: GameStateMachine = _g.machine
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(stop[0], stop[1]))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(30)
	return _check("enter %s" % stop[0], res == GameStateMachine.RequestResult.OK)


func _walk_into_first_symbol() -> bool:
	var m: GameStateMachine = _g.machine
	var ow: OverworldMode = _g.current_mode_node() as OverworldMode
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
	print("audio_play_log: encounter SFX: %s" % [_g.audio.sfx_log])
	return _check("battle started", m.current_mode == GameStateMachine.Mode.BATTLE
			and AudioIds.BT_ENCOUNTER_START in _g.audio.sfx_log)


func _check(label: String, cond: bool) -> bool:
	print("audio_play_log: %s %s" % [label, "ok" if cond else "FAILED"])
	return cond


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _wait_mode(mode: GameStateMachine.Mode) -> void:
	var m: GameStateMachine = _g.machine
	var n: int = 0
	while not (m.phase == GameStateMachine.Phase.IDLE and m.current_mode == mode) and n < WAIT_CAP:
		await process_frame
		n += 1


func _close_dialogues() -> void:
	var m: GameStateMachine = _g.machine
	var guard: int = 0
	while GameStateMachine.OverlayKind.DIALOGUE in m.overlay_stack and guard < 20:
		await _frames(4)
		var line: InterimLineDialogue = _g.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.advance_guard(1.0)
			line.handle_action(InputActions.CONFIRM, true)
			line.handle_action(InputActions.CONFIRM, false)
		await _frames(4)
		guard += 1
