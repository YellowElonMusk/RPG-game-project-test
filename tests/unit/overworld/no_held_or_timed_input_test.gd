## Story 105, AC-43 (accessibility): no overworld action needs a hold or a
## timed press. Static audit: the overworld's input handlers read only the
## action and its press edge, never a press duration or a time window.
## Flow audit: interaction, the checkpoint redirect, the camp and
## chapter-end prompts, and the Dialogue close all complete with single
## presses plus `move`. (The Dialogue's `input_guard` refuses a confirm in
## its first 0.15 s, a debounce, not a required hold: waiting is never
## needed to finish a flow, since any later press works.)
extends GdUnitTestSuite

## The scripts whose `handle_action` serves the overworld's flows.
const _HANDLERS: Array[String] = [
	"res://src/overworld/overworld_mode.gd",
	"res://src/game_state/overlays/interim_line_dialogue.gd",
	"res://src/game_state/modes/interim_camp_mode.gd",
]
## Source patterns that would mean a press is timed or held.
const _TIMED_PATTERNS: Array[String] = [
	"held_for", "hold_time", "_hold_s", "press_time", "pressed_at", "long_press",
	"double_tap", "is_action_pressed", "get_action_strength", "echo",
]
const _AT: Vector2 = ProbeFixture.OPEN_SPOT
const _AHEAD: Vector2 = ProbeFixture.OPEN_SPOT + Vector2(0.0, -1.0)


func test_no_handler_reads_a_press_duration_or_window() -> void:
	for path: String in _HANDLERS:
		var source: String = (load(path) as GDScript).source_code
		for pattern: String in _TIMED_PATTERNS:
			assert_bool(source.contains(pattern)).override_failure_message(
					"%s uses '%s'" % [path, pattern]).is_false()


func test_interaction_and_its_close_take_single_presses() -> void:
	var mode: OverworldMode = _facing([ProbeFixture.npc(_AHEAD)])
	_press(mode, InputActions.CONFIRM)
	var line: InterimLineDialogue = _line(mode)
	line.advance_guard(1.0)
	line.handle_action(InputActions.CONFIRM, true)
	assert_array(_machine(mode).overlay_stack).is_empty()


func test_the_checkpoint_redirect_takes_single_presses() -> void:
	var mode: OverworldMode = _mode([])
	var cp := CheckpointMarker.new()
	cp.marker_id = &"cp_audit"
	cp.requirement_flag = "audit_permit"
	cp.failure_outcome = CheckpointMarker.FailureOutcome.REDIRECT
	cp.blocked_rect = Rect2(11, 12, 2, 1)
	cp.position = Vector3(12.0, 0.0, 12.5)
	cp.return_marker = _AT
	mode.add_checkpoint(auto_free(cp))
	ProbeFixture.stand(mode, Vector2(12.0, 13.6), Vector2.UP)
	_press(mode, InputActions.CONFIRM)
	var line: InterimLineDialogue = _line(mode)
	line.advance_guard(1.0)
	line.handle_action(InputActions.CONFIRM, true)
	_run_to_idle(_machine(mode))
	assert_int(mode.table_state()).is_equal(OverworldMode.TableState.EXPLORING)
	assert_vector(mode.get_leader_position()).is_equal(_AT)


func test_the_camp_and_chapter_end_prompts_take_single_presses() -> void:
	var mode: OverworldMode = _facing([ProbeFixture.camp(_AHEAD)])
	_press(mode, InputActions.CONFIRM)
	_press(mode, InputActions.MOVE_RIGHT)
	_press(mode, InputActions.CONFIRM)  # No
	_press(mode, InputActions.CONFIRM)
	_press(mode, InputActions.CANCEL)
	_press(mode, InputActions.CONFIRM)
	_press(mode, InputActions.CONFIRM)  # Yes: rest
	assert_int(mode.camp_requests).is_equal(1)
	var camp: CampSpot = ProbeFixture.camp(_AHEAD)
	camp.is_region_default = true
	var cafe: OverworldMode = _facing([camp])
	var steps := ChapterSteps.new()
	var step := ChapterStep.new()
	step.id = "step_audit_final"
	steps.steps = [step] as Array[ChapterStep]
	cafe.set_chapter_steps(steps)
	cafe.world_state.chapter_step = step.id
	_press(cafe, InputActions.CONFIRM)
	_press(cafe, InputActions.MOVE_LEFT)
	_press(cafe, InputActions.CONFIRM)  # Yes: end the chapter
	assert_int(cafe.chapter_end_calls).is_equal(1)


## One press: the press edge, then the release.
func _press(mode: OverworldMode, action: StringName) -> void:
	mode.handle_action(action, true)
	mode.handle_action(action, false)


func _line(mode: OverworldMode) -> InterimLineDialogue:
	var line: InterimLineDialogue = auto_free(
			(load("res://src/game_state/overlays/interim_line_dialogue.tscn") as PackedScene).instantiate())
	add_child(line)
	line.setup(_machine(mode), DialogueLinePayload.new(mode.lines_said.back()))
	return line


func _facing(extras: Array) -> OverworldMode:
	var mode: OverworldMode = _mode(extras)
	ProbeFixture.stand(mode, _AT, Vector2.UP)
	return mode


func _mode(extras: Array) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode(extras))
	mode.grace_active = false
	return mode


func _machine(mode: OverworldMode) -> GameStateMachine:
	return mode.get("_machine")


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
