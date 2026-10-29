## Story 040, AC-15: a MapExit crossing and a contact on the same frame make
## only the exit request; contact is not checked and the symbols are not
## stepped that frame (ADR-0012 §5 per-frame order). Synthetic fixture, not
## a shipped map.
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_exit"
const _DECOY: String = "enc_fixture_decoy"
const _LEADER: Vector2 = Vector2(2.0, 5.0)
## Symbol start gap and leader step, in multiples of `body_radius`: the end
## gap is 1.5 r <= 2 r, so the frame is a contact.
const _GAP_R: float = 3.5
const _STEP_R: float = 2.0


func test_exit_and_contact_same_frame_only_exit_requested() -> void:
	_assert_exit_wins(OverworldConfig.new())


func test_exit_and_contact_same_frame_only_exit_requested_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.25
	_assert_exit_wins(cfg)


## Control: the same frame without the exit is a contact.
func test_same_fixture_without_exit_is_contact() -> void:
	var cfg := OverworldConfig.new()
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(spy, cfg, false)
	mode.step_frame(_dt(cfg), Vector2.RIGHT)
	assert_array(spy.encounter_ids()).is_equal([_ENC])
	assert_int(mode.exit_requests).is_equal(0)


func _assert_exit_wins(cfg: OverworldConfig) -> void:
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(spy, cfg, true)
	var decoy: SymbolBrain = mode.add_symbol(_DECOY, ContactFixture.brain(
			[Vector2(11.0, 9.0)], 5, cfg, false)).brain
	var hits: Array[StringName] = []
	mode.map_exit_requested.connect(func(id: StringName) -> void: hits.append(id))
	var touched: SymbolBrain = mode.get_symbol_brains()[0]
	var pos_before: Vector2 = touched.position
	var state_before: SymbolBrain.SubState = touched.sub_state

	mode.step_frame(_dt(cfg), Vector2.RIGHT)

	assert_array(hits).is_equal([&"exit_fixture"])
	assert_int(mode.exit_requests).is_equal(1)
	assert_int(spy.payloads.size()).is_equal(0)
	assert_int(mode.encounter_requests).is_equal(0)
	assert_int(touched.sub_state).is_equal(state_before)
	assert_bool(touched.contact_pending).is_false()
	assert_vector(touched.position).is_equal(pos_before)
	assert_int(touched.notice_tests_run).is_equal(0)
	assert_int(decoy.notice_tests_run).is_equal(0)
	# The fixture really is a contact this frame (swept test, same inputs).
	var leader_to: Vector2 = mode.get_leader_position()
	var d: float = OverworldMode.closest_approach(
			_LEADER, leader_to - _LEADER, pos_before, Vector2.ZERO)
	assert_bool(d <= 2.0 * cfg.body_radius).is_true()


func _mode(spy: RequestSpyMachine, cfg: OverworldConfig, with_exit: bool) -> OverworldMode:
	var ids: Array[String] = [_ENC, _DECOY]
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, _LEADER, ids))
	var r: float = cfg.body_radius
	mode.add_symbol(_ENC, ContactFixture.brain([_LEADER + Vector2(_GAP_R * r, 0.0)], 0, cfg, false))
	if with_exit:
		mode.add_map_exit(&"exit_fixture", Rect2(Vector2(_LEADER.x + r, _LEADER.y - 1.0),
				Vector2(_STEP_R * r, 2.0)))
	return mode


func _dt(cfg: OverworldConfig) -> float:
	return _STEP_R * cfg.body_radius / cfg.walk_speed
