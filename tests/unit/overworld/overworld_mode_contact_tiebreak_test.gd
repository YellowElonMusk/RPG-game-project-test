## Story 042, AC-17: two symbols in contact on the same frame -> the smaller
## closest-approach distance starts the encounter; on an exact tie the
## earlier marker does; on `transition_finished` after the thaw the other
## (Noticing) symbol is in Returning; the losing record is never requested.
extends GdUnitTestSuite

const _WIN: String = "enc_fixture_winner"
const _LOSE: String = "enc_fixture_loser"
## Leader on a cell centre so each symbol sits in a neighbouring cell.
const _LEADER: Vector2 = Vector2(3.5, 5.5)
## Offsets in multiples of `body_radius` (all < 2 r: touching).
const _NEAR_R: float = 1.2
const _FAR_R: float = 1.8
const _TIE_R: float = 1.6


## The smaller distance wins even though it is later in marker order.
func test_smaller_distance_starts_encounter() -> void:
	_assert_case(OverworldConfig.new(), false)


func test_exact_tie_earlier_marker_starts_encounter() -> void:
	_assert_case(OverworldConfig.new(), true)


func test_tiebreak_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.25
	_assert_case(cfg, false)
	_assert_case(cfg, true)


func _assert_case(cfg: OverworldConfig, tie: bool) -> void:
	var spy := RequestSpyMachine.new()
	var ids: Array[String] = [_WIN, _LOSE]
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(spy, cfg, _LEADER, ids))
	var r: float = cfg.body_radius
	var win_marker: int = 0 if tie else 1
	var lose_marker: int = 1 if tie else 0
	var win_off := Vector2(0.0, -(_TIE_R if tie else _NEAR_R) * r)
	var lose_off := Vector2((_TIE_R if tie else _FAR_R) * r, 0.0)
	# Loser registered first so marker order, not insertion order, decides.
	# It is not deaf: it notices the leader this frame (Noticing, still).
	var lose_path: Array[Vector2] = [_LEADER + lose_off]
	var win_path: Array[Vector2] = [_LEADER + win_off]
	var loser: SymbolBrain = mode.add_symbol(_LOSE, ContactFixture.brain(
			lose_path, lose_marker, cfg, false)).brain
	var winner: SymbolBrain = mode.add_symbol(_WIN, ContactFixture.brain(
			win_path, win_marker, cfg, true)).brain

	mode.step_frame(1.0 / 60.0, Vector2.ZERO)

	assert_array(spy.encounter_ids()).is_equal([_WIN])
	assert_int(mode.get_state()).is_equal(OverworldMode.State.FROZEN)
	assert_int(loser.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_bool(loser.contact_pending).is_false()

	spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)  # After the thaw.

	assert_int(loser.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	assert_int(winner.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)
	assert_array(spy.encounter_ids()).is_equal([_WIN])
