## Story 010, AC-8: input during OUT, SWAP and IN reaches nobody; the first
## action after `transition_finished` is delivered. Written to the QA Test
## Cases in
## `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`
## -- no new cases invented.
extends GdUnitTestSuite

const _PHASES: Array = [["OUT"], ["SWAP"], ["IN"]]


## AC-8 (lock): neither the discrete nor the continuous path is delivered
## while `phase != IDLE`, in any of the three phases.
func test_no_delivery_during_phase(phase_name: String, test_parameters := _PHASES) -> void:
	# Arrange: Overworld -> Battle in progress, stopped in the given phase,
	# with a counting stub mode bound as the loader's current mode node.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var mode: StubOverworldMode = auto_free(StubOverworldMode.new())
	loader.current_mode_node_value = mode
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_advance_to_phase(machine, cfg, phase_name)

	# Act: both the discrete and the continuous path, while stopped in-phase.
	source.press(&"confirm")
	source.release(&"confirm")
	source.move_vector = Vector2(1.0, 0.0)

	# Assert: nothing reaches the mode (or, trivially, any overlay -- none is
	# open here, and dispatch checks `phase` before it ever would look).
	assert_int(mode.handle_action_count).override_failure_message(
			"expected no handle_action delivery during %s" % phase_name).is_equal(0)
	assert_vector(machine.get_move_vector(mode)).is_equal(Vector2.ZERO)
	assert_bool(machine.is_input_owner(mode)).is_false()

	_finish_transition_to_idle(machine)


## AC-8 (unlock): the lock clears before `transition_finished` emits, so an
## action pressed synchronously from a listener on that signal is delivered
## to the destination mode. Also covers this test case's edge cases: the four
## NOT-consumed signals reach no receiver, and with an overlay open the
## overlay (not the mode) gets the discrete action while the mode's move
## vector stays zero.
func test_first_action_after_finished_delivered() -> void:
	# Arrange: Overworld -> Camp (a plain fade; the stub loader's poll_swap()
	# defaults to DONE on its first call, so no scripting is needed).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var destination_mode: StubCampMode = auto_free(StubCampMode.new())
	loader.current_mode_node_value = destination_mode
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	machine.transition_finished.connect(
			func(_to: GameStateMachine.Mode) -> void: source.press(&"confirm"))

	# Act
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP, null)
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	# Assert: the first action after transition_finished landed exactly once.
	assert_int(destination_mode.handle_action_count).is_equal(1)
	assert_bool(destination_mode.last_action == &"confirm").is_true()
	assert_bool(destination_mode.last_pressed).is_true()
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)

	# Edge case: action_held, device_restored, focus_gained and
	# active_device_changed are NOT consumed -- emitting them reaches nobody.
	source.hold(&"confirm")
	source.restore_device()
	source.gain_focus()
	source.change_active_device(0, &"gamepad_xbox")
	assert_int(destination_mode.handle_action_count).override_failure_message(
			"a NOT-consumed signal reached a receiver").is_equal(1)

	# Edge case: with an overlay open, the mode no longer owns input and the
	# overlay -- not the mode -- gets the discrete action.
	var overlay: StubOverlay = auto_free(StubOverlay.new())
	loader.current_overlay_node_value = overlay
	var overlay_result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU, null)
	assert_int(overlay_result).is_equal(GameStateMachine.RequestResult.OK)

	assert_vector(machine.get_move_vector(destination_mode)).is_equal(Vector2.ZERO)
	source.press(&"cancel")
	assert_int(overlay.handle_action_count).is_equal(1)
	assert_int(destination_mode.handle_action_count).override_failure_message(
			"the mode received an action while an overlay was open").is_equal(1)


## Advances `machine` from freshly-requested OUT to the given phase_name
## (`"OUT"`, `"SWAP"` or `"IN"`), scripted for an Overworld -> Battle
## `battle_wipe`, with the stub loader held PENDING for SWAP.
func _advance_to_phase(machine: GameStateMachine, cfg: TransitionConfig, phase_name: String) -> void:
	match phase_name:
		"OUT":
			pass   # already stopped at the start of OUT
		"SWAP":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
		"IN":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
			machine.tick(1.0 / 60.0)                   # poll #2: DONE -> begins IN
		_:
			assert_bool(false).override_failure_message(
					"unknown phase_name: %s" % phase_name).is_true()

	var expected_phase: GameStateMachine.Phase = GameStateMachine.Phase.OUT
	if phase_name == "SWAP":
		expected_phase = GameStateMachine.Phase.SWAP
	elif phase_name == "IN":
		expected_phase = GameStateMachine.Phase.IN
	assert_int(machine.phase).is_equal(expected_phase)


## Bounded 1/60s-tick loop until the transition that was stopped mid-flight
## reaches IDLE in BATTLE.
func _finish_transition_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
