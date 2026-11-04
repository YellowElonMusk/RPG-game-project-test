extends SceneTree
## Onboarding evidence: boots `GameRoot`, starts a New Game, and saves the
## overworld controls strip, the first-symbol hint on the Rue de Rivoli, the
## first battle's "How to fight" card and Bureaucratia's rule card. Needs a
## window and a GPU, and the `tutorial_hints` setting On (the default):
##
##   godot --path . -s res://tools/capture/onboarding_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/onboarding/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://onboarding_capture_saves"
const SIZE := Vector2i(1280, 720)
const WAIT_CAP: int = 1200
const DT: float = 1.0 / 60.0
const SEGMENT: Array = ["map_paris_segment_placeholder", &"from_town"]

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
	await _frames(200)  # past the name card
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	ok = _check("controls strip", not ow.controls_hint_text().is_empty()) and ok
	await _shot("01-overworld-controls-strip")
	# The first patrolling symbol within its notice distance barks the hint.
	ok = await _enter(SEGMENT) and ok
	ow = _root_node.current_mode_node() as OverworldMode
	ow.set_process(false)
	var source: EncounterSource = ow.get_encounter_sources()[0]
	ow.grace_active = true
	ow.set_leader_position(source.brain.position + Vector2(0.0, ow.config.see_m() - 0.5))
	ow.step_frame(DT, Vector2.ZERO)
	await _frames(30)
	ok = _check("symbol hint", ow.bark_text == TutorialHints.SYMBOLS_TEXT) and ok
	await _shot("02-overworld-symbol-hint")
	# Walk into it: the first battle shows its two cards before round 1.
	ow.grace_active = false
	ow.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	var guard: int = 0
	while m.phase == GameStateMachine.Phase.IDLE and guard < 120:
		ow.step_frame(DT, Vector2.UP)
		await process_frame
		guard += 1
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	var battle_mode := _root_node.current_mode_node() as BattleMode
	ok = _check("battle", battle_mode != null) and ok
	if battle_mode != null:
		await _frames(60)
		var card: TutorialCard = battle_mode.tutorial_card()
		ok = _check("how-to card", card.visible and card.title_text() == TutorialHints.FIRST_BATTLE_TITLE) and ok
		await _shot("03-first-battle-card")
		(card.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
		await _frames(20)
		ok = _check("rule card", card.visible and card.title_text() == "Bureaucratia's rule") and ok
		await _shot("04-faction-rule-card")
	_finish(ok)


func _finish(ok: bool) -> void:
	print("onboarding_capture: %s; wrote %s" % ["PASS" if ok else "FAIL", _out])
	quit(0 if ok else 1)


func _enter(stop: Array) -> bool:
	var m: GameStateMachine = _root_node.machine
	var res: int = m.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(stop[0], stop[1]))
	await _frames(5)
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _frames(200)
	return _check("enter %s" % stop[0], res == GameStateMachine.RequestResult.OK)


func _check(label: String, cond: bool) -> bool:
	print("onboarding_capture: %s %s" % [label, "ok" if cond else "FAILED"])
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
