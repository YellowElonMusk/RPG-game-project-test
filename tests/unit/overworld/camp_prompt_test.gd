## Story 113, AC-45d (UI; GDD States CampPrompt, UI Requirements): `confirm`
## at a CampSpot opens "Rest here?" with Yes focused; `cancel` closes it with
## no camp request; No closes it too. Also GDD rule 13a: walking into a
## CampSpot's safe zone registers the camp with Game State. Runs on the
## Town map's café.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _TOWN: String = "res://data/maps/paris_town_placeholder.tscn"
const _CAFE: String = "camp_paris_cafe"
const _DT: float = 1.0 / 60.0


func test_confirm_at_the_cafe_opens_the_prompt_with_yes_focused() -> void:
	var mode: OverworldMode = _at_cafe(GameStateFixtures.make_machine_in_overworld()["machine"])
	assert_bool(mode.handle_action(InputActions.CONFIRM, true)).is_true()
	assert_object(mode.get_camp_prompt_camp()).is_not_null()
	assert_str(mode.get_camp_prompt_camp().camp_id).is_equal(_CAFE)
	assert_int(mode.camp_prompt_focus).is_equal(OverworldMode.CampChoice.YES)
	assert_bool(mode.is_exploring()).is_false()


func test_cancel_closes_the_prompt_with_no_camp_request() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _at_cafe(machine)
	mode.config.camp_mode_enabled = true
	mode.handle_action(InputActions.CONFIRM, true)
	assert_bool(mode.handle_action(InputActions.CONFIRM, false)).is_true()  # release consumed
	assert_bool(mode.handle_action(InputActions.CANCEL, true)).is_true()
	assert_object(mode.get_camp_prompt_camp()).is_null()
	assert_bool(mode.is_exploring()).is_true()
	assert_int(mode.camp_requests).is_equal(0)
	assert_int(machine.targets.size()).is_equal(0)


func test_no_closes_the_prompt_with_no_camp_request() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _at_cafe(machine)
	mode.config.camp_mode_enabled = true
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.MOVE_RIGHT, true)
	assert_int(mode.camp_prompt_focus).is_equal(OverworldMode.CampChoice.NO)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_object(mode.get_camp_prompt_camp()).is_null()
	assert_int(machine.targets.size()).is_equal(0)


func test_yes_requests_the_camp_mode_with_the_camp_id() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _at_cafe(machine)
	mode.config.camp_mode_enabled = true
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(machine.targets).is_equal([GameStateMachine.Mode.CAMP])
	assert_str((machine.payloads[0] as CampEntryPayload).camp_id).is_equal(_CAFE)


func test_yes_without_a_camp_mode_registers_the_camp_and_stays() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _at_cafe(machine)
	mode.config.camp_mode_enabled = false
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, true)
	assert_str(machine.last_camp_id).is_equal(_CAFE)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_bool(mode.is_exploring()).is_true()


func test_walking_into_the_safe_zone_registers_the_camp() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = _mode(machine)
	var cafe: Vector2 = mode.get_map().camp_spots()[0].ground_position(mode.get_map())
	mode.set_leader_position(cafe + Vector2(0.0, mode.config.safe_radius_m + 0.5))
	mode.step_frame(_DT, Vector2.ZERO)
	assert_str(machine.last_camp_id).is_not_equal(_CAFE)
	for i: int in 30:
		mode.step_frame(_DT, Vector2.UP)
	assert_str(machine.last_camp_id).is_equal(_CAFE)


func test_nothing_in_reach_does_nothing() -> void:
	var machine := RequestSpyMachine.new()
	var mode: OverworldMode = _mode(machine)
	mode.set_leader_position(Vector2(3.5, 5.5))
	assert_object(mode.probe()).is_null()
	mode.handle_action(InputActions.CONFIRM, true)
	assert_object(mode.get_camp_prompt_camp()).is_null()
	assert_int(machine.targets.size()).is_equal(0)


## The leader 1 m south of the café, facing it.
func _at_cafe(machine: GameStateMachine) -> OverworldMode:
	var mode: OverworldMode = _mode(machine)
	var cafe: Vector2 = mode.get_map().camp_spots()[0].ground_position(mode.get_map())
	mode.set_leader_position(cafe + Vector2(0.0, 1.3))
	mode.set_leader_facing(Vector2.UP)
	return mode


func _mode(machine: GameStateMachine) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.load_map((load(_TOWN) as PackedScene).instantiate() as OverworldMap)
	return mode
