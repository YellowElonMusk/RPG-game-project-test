## Story 038, AC-13: contact calls `start_encounter` exactly once with the
## symbol's own `enc_` ID; the descriptor is identical whatever the contact
## direction or which body moved (GDD rule 6).
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_a"
const _OTHER: String = "enc_fixture_b"
const _Y: float = 5.0
## Gap between centres at frame start, and each mover's displacement, as
## multiples of `body_radius`: 3.5 r apart, closing by 2 r -> 1.5 r <= 2 r.
const _GAP_R: float = 3.5
const _CLOSE_R: float = 2.0


func test_leader_walks_into_still_symbol_calls_once() -> void:
	_assert_case(OverworldConfig.new(), 0)


func test_symbol_walks_into_still_leader_calls_once() -> void:
	_assert_case(OverworldConfig.new(), 1)


func test_both_moving_calls_once() -> void:
	_assert_case(OverworldConfig.new(), 2)


func test_descriptor_identical_across_cases_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.25
	var first: EncounterDescriptor = _assert_case(cfg, 0)
	for c in [1, 2]:
		var d: EncounterDescriptor = _assert_case(cfg, c)
		assert_bool(_same(first, d)).override_failure_message("case %d differs" % c).is_true()


func test_closest_approach_zero_relative_motion_is_start_distance() -> void:
	var d: float = OverworldMode.closest_approach(Vector2(0, 0), Vector2(1, 0), Vector2(3, 4), Vector2(1, 0))
	assert_float(d).is_equal_approx(5.0, 1e-6)


## case 0 leader moves, 1 symbol moves, 2 both. Returns the descriptor.
func _assert_case(cfg: OverworldConfig, c: int) -> EncounterDescriptor:
	var spy: RequestSpyMachine = RequestSpyMachine.new()
	var r: float = cfg.body_radius
	var leader := Vector2(2.0, _Y)
	var sym := leader + Vector2(_GAP_R * r, 0.0)
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, leader, [_ENC, _OTHER]))
	# A far, deaf decoy with a different record, earlier in marker order.
	mode.add_symbol(_OTHER, ContactFixture.brain([Vector2(10.0, 1.0)], 0, cfg, true))
	var close: float = _CLOSE_R * r if c != 2 else _CLOSE_R * r * 0.5
	var path: Array[Vector2] = [sym]
	if c != 0:
		path = [sym, sym + Vector2(-5.0, 0.0)]
	mode.add_symbol(_ENC, ContactFixture.brain(path, 1, cfg, true))
	var dt: float = close / cfg.v_patrol() if c != 0 else close / cfg.walk_speed
	var input := Vector2.ZERO
	if c == 0:
		input = Vector2.RIGHT
	elif c == 2:
		input = Vector2(cfg.v_patrol() / cfg.walk_speed, 0.0)
	mode.step_frame(dt, input)
	mode.step_frame(dt, input)  # Frozen: no second call.
	assert_array(spy.encounter_ids()).is_equal([_ENC])
	assert_int(spy.targets[0]).is_equal(GameStateMachine.Mode.BATTLE)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.FROZEN)
	return (spy.payloads[0] as BattleEntryPayload).descriptor


func _same(a: EncounterDescriptor, b: EncounterDescriptor) -> bool:
	return a.encounter_id == b.encounter_id and a.enemy_ids == b.enemy_ids \
			and a.battle_stage_id == b.battle_stage_id and a.faction_id == b.faction_id \
			and a.is_boss == b.is_boss and a.can_flee == b.can_flee \
			and a.retreat_allowed == b.retreat_allowed
