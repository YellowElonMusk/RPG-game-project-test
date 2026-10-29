## Story 071, AC-28b (GDD rule 10 Redirect, rule 7 grace): with the
## requirement unmet and a `redirect` or `queue` outcome, the line plays;
## on its close the state is Redirecting, input is locked (a transition is
## running), and under the same-instance fade the leader lands on the
## return marker facing away, followers snapped and the camera told to
## snap. Grace starts on `transition_finished`, Noticing/Chasing symbols
## switch to Returning, every other symbol is untouched, and no
## `mode_entered` fires. One `confirm` closes the line: no timed or held
## input.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _ENC_NOTICER: String = "enc_fixture_noticer"
const _ENC_PATROL: String = "enc_fixture_patroller"
const _CP: StringName = &"cp_fixture_gate"
const _LEADER: Vector2 = Vector2(3.5, 5.5)
const _RETURN: Vector2 = Vector2(9.5, 7.5)
const _DT: float = 1.0 / 60.0


func test_redirect_line_then_locked_fade_to_the_return_marker() -> void:
	_run(CheckpointMarker.FailureOutcome.REDIRECT, "No Form 27-B? Back of the queue.")


func test_queue_line_then_the_same_redirect() -> void:
	_run(CheckpointMarker.FailureOutcome.QUEUE, "Now serving 000 003. You are 4 812 117.")


func test_default_line_names_the_missing_requirement() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var mode: OverworldMode = _mode(env["machine"], CheckpointMarker.FailureOutcome.REDIRECT, "")
	mode.confirm_checkpoint(_CP)
	assert_str(mode.lines_said[0]).contains("form_27b")


func _run(outcome: CheckpointMarker.FailureOutcome, line: String) -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var mode: OverworldMode = _mode(machine, outcome, line)
	var cfg: OverworldConfig = mode.config
	# A noticing symbol near the leader, and a deaf patroller far away.
	var noticer := SymbolBrain.new(PackedVector2Array([Vector2(1.5, 7.0)]), SymbolBrain.PathMode.LOOP, 0)
	mode.add_symbol(_ENC_NOTICER, noticer)
	var patroller: SymbolBrain = ContactFixture.brain(
			[Vector2(0.5, 1.5), Vector2(0.5, 9.5)], 1, cfg, true)
	mode.add_symbol(_ENC_PATROL, patroller)
	mode.grace_active = false
	mode.step_frame(_DT, Vector2.ZERO)
	assert_int(noticer.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	var mode_entered: Array[int] = []
	machine.mode_entered.connect(func(to: GameStateMachine.Mode) -> void: mode_entered.append(to))
	var placed: Array[Vector2] = []
	mode.party_placed.connect(func(at: Vector2) -> void: placed.append(at))

	# Act 1: the line.
	mode.confirm_checkpoint(_CP)
	assert_array(mode.lines_said).is_equal([line])
	assert_array(machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	assert_bool(mode.is_exploring()).is_false()
	var patrol_before: Dictionary = _brain_state(patroller)
	# Act 2: one confirm closes it; the redirect starts on that same frame.
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.REDIRECTING)
	assert_int(machine.phase).is_not_equal(GameStateMachine.Phase.IDLE)
	assert_bool(machine.is_in_mode_fade()).is_true()
	assert_bool(mode.is_exploring()).is_false()
	# Act 3: the fade runs out.
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).is_true()

	assert_vector(mode.get_leader_position()).is_equal(_RETURN)
	assert_vector(mode.get_leader_facing()).is_equal(Vector2.DOWN)
	assert_array(placed).is_equal([_RETURN])
	var followers: Array[Vector2] = mode.get_follower_positions()
	assert_int(followers.size()).is_equal(cfg.max_followers)
	assert_vector(followers[0]).is_equal_approx(_RETURN + Vector2.UP * cfg.follower_spacing_m,
			Vector2.ONE * 1e-4)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)
	assert_float(mode.get_grace_left()).is_equal(cfg.encounter_grace_s)
	assert_int(noticer.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	assert_dict(_brain_state(patroller)).is_equal(patrol_before)
	assert_array(mode_entered).is_empty()
	assert_bool(mode.is_checkpoint_open(_CP)).is_false()


func _brain_state(b: SymbolBrain) -> Dictionary:
	return {"sub_state": b.sub_state, "position": b.position, "next": b.next_index(),
			"cooldown": b.cooldown_left(), "stun": b.stun_left(), "notice": b.notice_elapsed()}


func _mode(machine: GameStateMachine, outcome: CheckpointMarker.FailureOutcome,
		line: String) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			machine, OverworldConfig.new(), _LEADER, [_ENC_NOTICER, _ENC_PATROL]))
	mode.world_state = WorldState.new()
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = _CP
	cp.requirement_item_id = "form_27b"
	cp.failure_outcome = outcome
	cp.failure_line = line
	cp.blocked_rect = Rect2(9, 4, 2, 1)
	cp.position = Vector3(9.5, 0.0, 5.3)
	cp.return_marker = _RETURN
	cp.return_facing = Vector2.DOWN
	mode.add_checkpoint(cp)
	return mode
