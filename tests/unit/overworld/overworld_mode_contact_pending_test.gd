## Story 041, AC-16: `start_encounter` rejected (REJECTED_BUSY) for 30
## frames while the bodies overlap -> the symbol does not move and keeps its
## sub-state, the request is retried every frame, one rejection is logged,
## and the first accepted frame enters Frozen.
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_pending"
const _LEADER: Vector2 = Vector2(2.0, 5.0)
const _REJECTED_FRAMES: int = 30
const _DT: float = 1.0 / 60.0
## Start gap in multiples of `body_radius` (< 2 r: overlapping).
const _GAP_R: float = 1.5


func test_rejected_thirty_frames_holds_retries_logs_once_then_frozen() -> void:
	_assert_pending(OverworldConfig.new())


func test_rejected_thirty_frames_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.25
	_assert_pending(cfg)


func _assert_pending(cfg: OverworldConfig) -> void:
	var spy := RequestSpyMachine.new()
	for i in _REJECTED_FRAMES:
		spy.scripted.append(GameStateMachine.RequestResult.REJECTED_BUSY)
	var ids: Array[String] = [_ENC]
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, _LEADER, ids))
	var start: Vector2 = _LEADER + Vector2(_GAP_R * cfg.body_radius, 0.0)
	# A walking patrol (deaf, so it would keep walking if it were not held).
	var path: Array[Vector2] = [start, start + Vector2(5.0, 0.0)]
	var brain: SymbolBrain = mode.add_symbol(_ENC, ContactFixture.brain(path, 0, cfg, true)).brain
	var state_before: SymbolBrain.SubState = brain.sub_state

	mode.step_frame(_DT, Vector2.ZERO)
	var held_at: Vector2 = brain.position
	assert_bool(brain.contact_pending).is_true()
	assert_int(spy.payloads.size()).is_equal(1)
	for frame in range(2, _REJECTED_FRAMES + 1):
		mode.step_frame(_DT, Vector2.ZERO)
		assert_vector(brain.position).override_failure_message(
				"moved on frame %d" % frame).is_equal(held_at)
		assert_int(brain.sub_state).is_equal(state_before)
		assert_float(brain.last_distance_moved).is_equal(0.0)
		assert_int(spy.payloads.size()).override_failure_message(
				"not retried on frame %d" % frame).is_equal(frame)
		assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)
	assert_int(mode.rejections_logged).is_equal(1)

	mode.step_frame(_DT, Vector2.ZERO)  # Frame 31: accepted.
	assert_int(spy.payloads.size()).is_equal(_REJECTED_FRAMES + 1)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.FROZEN)
	assert_bool(brain.contact_pending).is_false()
	assert_vector(brain.position).is_equal(held_at)
	assert_int(mode.rejections_logged).is_equal(1)
	for id: String in spy.encounter_ids():
		assert_str(id).is_equal(_ENC)
