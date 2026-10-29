## Story 045, AC-19b: a Stunned symbol overlapping the leader starts no
## encounter during `flee_grace_s`; Stunned at `flee_grace_s - dt`,
## Returning at `flee_grace_s + dt` (GDD rule 5 Stunned row, rule 7).
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_clerk"
const _DT: float = 0.05
const _FRAMES: int = 10


func test_stunned_overlap_no_encounter_default_config() -> void:
	_assert_case(OverworldConfig.new())


func test_stunned_overlap_no_encounter_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.flee_grace_s = 2.0
	cfg.body_radius = 0.4
	_assert_case(cfg)


func _assert_case(cfg: OverworldConfig) -> void:
	var spy := RequestSpyMachine.new()
	var leader := Vector2(4.5, 5.5)
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, leader, [_ENC]))
	var source: EncounterSource = mode.add_symbol(_ENC,
			SymbolBrain.new(PackedVector2Array([Vector2(5.0, 5.5)]), SymbolBrain.PathMode.LOOP))
	mode.start_encounter(_ENC, source)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.FLED)
	spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	# Isolate the stun from encounter grace (story 047's rule).
	mode.grace_active = false
	var b: SymbolBrain = source.brain
	var hold: float = cfg.flee_grace_s - _DT
	for i in _FRAMES:
		mode.set_leader_position(b.position)  # Directly under the leader.
		mode.step_frame(hold / float(_FRAMES), Vector2.ZERO)
		assert_int(spy.payloads.size()).is_equal(1)
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.STUNNED)
	mode.step_frame(2.0 * _DT, Vector2.ZERO)
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	assert_int(spy.payloads.size()).is_equal(1)
