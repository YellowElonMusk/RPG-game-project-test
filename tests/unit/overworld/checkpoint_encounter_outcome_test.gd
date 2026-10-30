## Story 072, AC-28c (GDD rule 10, `encounter` outcome): with the
## requirement unmet, `confirm` at the checkpoint starts its linked
## encounter, and a Victory opens it (cells freed, kept open in
## `WorldState`). Fled leaves it closed and puts the leader on its return
## marker; a met requirement opens it with no fight.
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_counter"
const _CP: StringName = &"cp_fixture_boom"
const _FLAG: String = "fixture_permit"
const _LEADER: Vector2 = Vector2(5.5, 6.5)
const _RETURN: Vector2 = Vector2(5.5, 8.0)


func test_unmet_requirement_starts_the_linked_encounter() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.confirm_checkpoint(_CP)
	assert_array(machine.encounter_ids()).is_equal([_ENC])
	assert_bool(mode.is_checkpoint_open(_CP)).is_false()
	assert_bool(mode.get_walk_grid().is_walkable(Vector2i(5, 4))).is_false()


func test_confirm_facing_the_checkpoint_starts_it_through_probe() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.set_leader_facing(Vector2.UP)
	assert_object(mode.probe()).is_instanceof(CheckpointMarker)
	assert_bool(mode.handle_action(InputActions.CONFIRM, true)).is_true()
	assert_array(machine.encounter_ids()).is_equal([_ENC])


func test_victory_opens_the_checkpoint_for_good() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.confirm_checkpoint(_CP)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.is_checkpoint_open(_CP)).is_true()
	assert_bool(mode.world_state.is_checkpoint_open("", _CP)).is_true()
	# Story 055 registry: the Victory sets the requirement flag (`counter_cleared`).
	assert_bool(mode.world_state.has_flag(_FLAG)).is_true()
	for cell: Vector2i in [Vector2i(5, 4), Vector2i(6, 4)]:
		assert_bool(mode.get_walk_grid().is_walkable(cell)).is_true()
	# An open checkpoint drops out of probe() and confirm starts nothing.
	mode.set_leader_facing(Vector2.UP)
	assert_object(mode.probe()).is_null()
	mode.confirm_checkpoint(_CP)
	assert_int(machine.payloads.size()).is_equal(1)


func test_fled_leaves_it_closed_and_returns_the_leader() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.confirm_checkpoint(_CP)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.FLED)
	assert_bool(mode.is_checkpoint_open(_CP)).is_false()
	assert_bool(mode.get_walk_grid().is_walkable(Vector2i(5, 4))).is_false()
	assert_vector(mode.get_leader_position()).is_equal(_RETURN)
	assert_vector(mode.get_leader_facing()).is_equal(Vector2.DOWN)


func test_met_requirement_opens_it_with_no_fight() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.world_state.set_flag(_FLAG)
	mode.confirm_checkpoint(_CP)
	assert_int(machine.payloads.size()).is_equal(0)
	assert_bool(mode.is_checkpoint_open(_CP)).is_true()


func test_a_checkpoint_opened_earlier_loads_open() -> void:
	var ws := WorldState.new()
	ws.open_checkpoint("", _CP)
	var mode: OverworldMode = _mode(RequestSpyMachine.new(), ws)
	assert_bool(mode.is_checkpoint_open(_CP)).is_true()
	assert_bool(mode.get_walk_grid().is_walkable(Vector2i(5, 4))).is_true()


## A mode on an open grid with the leader just south of a two-cell boom at
## (5..6, 4), whose `encounter` outcome fights `_ENC`.
func _mode(machine: GameStateMachine, ws: WorldState = null) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			machine, OverworldConfig.new(), _LEADER, [_ENC]))
	mode.world_state = ws if ws != null else WorldState.new()
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = _CP
	cp.requirement_flag = _FLAG
	cp.failure_outcome = CheckpointMarker.FailureOutcome.ENCOUNTER
	cp.linked_encounter_id = _ENC
	cp.blocked_rect = Rect2(5, 4, 2, 1)
	cp.position = Vector3(5.5, 0.0, 5.3)
	cp.return_marker = _RETURN
	cp.return_facing = Vector2.DOWN
	mode.add_checkpoint(cp)
	return mode
