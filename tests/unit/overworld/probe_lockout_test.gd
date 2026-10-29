## Story 013, AC-7c (GDD rule 3 Lockouts): during a transition, or with any
## overlay open (Menu, Dialogue) or the CampPrompt up, `probe()` is not
## called and `confirm` starts nothing, even with a target in reach.
extends GdUnitTestSuite

const _NPC_AT: Vector2 = Vector2(13.0, 14.5)  # 1 m east of ProbeFixture.OPEN_SPOT


func test_no_probe_during_a_transition() -> void:
	var ctx: Array = _ready_at_npc()
	var machine: GameStateMachine = ctx[0]
	var mode: OverworldMode = ctx[1]
	assert_int(machine.request_in_mode_fade(func() -> void: pass)).is_equal(GameStateMachine.RequestResult.OK)
	_assert_locked(mode)


func test_no_probe_with_the_menu_open() -> void:
	var ctx: Array = _ready_at_npc()
	(ctx[0] as GameStateMachine).open_overlay(GameStateMachine.OverlayKind.MENU)
	_assert_locked(ctx[1])


func test_no_probe_with_a_dialogue_open() -> void:
	var ctx: Array = _ready_at_npc()
	var mode: OverworldMode = ctx[1]
	mode.say("A line already up.")
	_assert_locked(mode, 1)


func test_no_probe_with_the_camp_prompt_up() -> void:
	var ctx: Array = _ready_at_npc()
	var mode: OverworldMode = ctx[1]
	mode.set_camp_prompt_open(true)
	_assert_locked(mode)


func test_unlocked_confirm_does_probe() -> void:
	var ctx: Array = _ready_at_npc()
	var mode: OverworldMode = ctx[1]
	var before: int = mode.probe_calls
	mode.handle_action(InputActions.CONFIRM, true)
	assert_int(mode.probe_calls).is_equal(before + 1)
	assert_array(mode.lines_said).is_equal(["Fixture line."])


func _ready_at_npc() -> Array:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([ProbeFixture.npc(_NPC_AT)], machine))
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	return [machine, mode]


func _assert_locked(mode: OverworldMode, lines_before: int = 0) -> void:
	var before: int = mode.probe_calls
	mode.handle_action(InputActions.CONFIRM, true)
	assert_int(mode.probe_calls).is_equal(before)
	assert_int(mode.lines_said.size()).is_equal(lines_before)
	assert_int(mode.encounter_requests).is_equal(0)
