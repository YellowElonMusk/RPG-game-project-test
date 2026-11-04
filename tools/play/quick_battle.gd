extends SceneTree
## Quick battle (battle.bat): boots `GameRoot`, starts a New Game, walks the
## squad into the first patrol on a street map and hands the fight to the
## player, music and all. After the fight the game carries on as normal.
##
##   godot --path . -s res://tools/play/quick_battle.gd [-- --map=map_london_segment_placeholder]

const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const DEFAULT_MAP: String = "map_paris_segment_placeholder"
const ENTRY: StringName = &"from_town"
const DT: float = 1.0 / 60.0
const WAIT_CAP: int = 1200

var _root_node: GameRoot = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map_id: String = DEFAULT_MAP
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.substr(6)
	_root_node = (load(GAME_ROOT_SCENE) as PackedScene).instantiate() as GameRoot
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine
	await _wait_mode(GameStateMachine.Mode.TITLE)
	(_root_node.current_mode_node() as TitleMode)._on_new_game_pressed()
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(map_id, ENTRY))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(30)
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	if ow == null or ow.get_encounter_sources().is_empty():
		push_error("quick_battle: no patrol on %s" % map_id)
		return
	ow.set_process(false)
	var source: EncounterSource = ow.get_encounter_sources()[0]
	ow.grace_active = false
	ow.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	var guard: int = 0
	while m.phase == GameStateMachine.Phase.IDLE and guard < 120:
		ow.step_frame(DT, Vector2.UP)
		await process_frame
		guard += 1
	ow.set_process(true)
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	print("quick_battle: battle music = %s" % _root_node.audio.current_music_id)


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
