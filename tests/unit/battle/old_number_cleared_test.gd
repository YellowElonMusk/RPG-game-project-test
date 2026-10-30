## Story 064 (GDD sprite-camera-presentation AC-59; ADR-0006 §3/§7): two
## consecutive latched beats on the same target. On the second beat's impact
## frame the first beat's number is removed, and no number is over the target
## from that frame until the second beat ends.
extends GdUnitTestSuite


func _run(config: PresentationConfig) -> void:
	var kit := ReplayTestKit.new(config, 0.3)
	var numbers := BeatNumbers.new()
	numbers.bind(kit.controller)
	var target: Combatant = kit.enemies[0]
	var over: Array[String] = []
	kit.emit_hit(kit.squad[0], target, 5)
	kit.emit_hit(kit.squad[1], target, 7)
	kit.emit_turn(kit.enemies[1])
	assert_bool(kit.controller.request_latch()).is_true()
	for guard: int in 2000:
		if kit.controller.get_state() == BattleReplayController.State.IDLE:
			break
		kit.step()
		over.append(numbers.number_over(target))
	var plans := kit.plans()
	assert_int(plans.size()).is_equal(2)
	var end1: int = kit.frames_of("beat_finished", plans[0])[0]
	var impact2: int = kit.frames_of("beat_impact", plans[1])[0]
	var end2: int = kit.frames_of("beat_finished", plans[1])[0]
	assert_int(impact2).is_greater(end1)
	# The first beat's number shows from its end up to (not including) the second impact.
	for f: int in range(end1, impact2):
		assert_str(over[f - 1]).is_equal(BeatPlan.number_text(-5))
	# From the second impact until the second beat ends: no number at all.
	for f: int in range(impact2, end2):
		assert_str(over[f - 1]).is_equal("")
	assert_str(over[end2 - 1]).is_equal(BeatPlan.number_text(-7))


func test_second_beat_impact_clears_first_number_default_config() -> void:
	_run(PresentationConfig.new())


func test_second_beat_impact_clears_first_number_alt_config() -> void:
	var c := PresentationConfig.new()
	c.reaction_hold = 0.22
	c.beat_min = 0.48
	c.ff_mult = 2.4
	_run(c)


func test_resync_clears_all_numbers() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
	var numbers := BeatNumbers.new()
	numbers.bind(kit.controller)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.emit_turn(kit.enemies[1])
	kit.run_until_idle()
	assert_str(numbers.number_over(kit.enemies[0])).is_equal("-5")
	kit.controller.resync()
	assert_str(numbers.number_over(kit.enemies[0])).is_equal("")
