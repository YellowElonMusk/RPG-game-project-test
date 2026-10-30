## Story 042 (GDD sprite-camera-presentation AC-38; ADR-0006 §6): every
## press during a replay latches, un-latches or produces exactly one
## refusal; the indicator is passive exactly while no press is effective and
## shows on exactly the replay's frames.
extends GdUnitTestSuite



func _kit_with_replay() -> ReplayTestKit:
	var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.emit_hit(kit.squad[1], kit.enemies[1], 5)
	kit.emit_turn(kit.squad[0])
	kit.step(1)
	return kit


func test_confirm_fast_forward_and_click_each_latch_while_active() -> void:
	for action: StringName in [ReplayInputRouter.ACTION_CONFIRM, ReplayInputRouter.ACTION_FAST_FORWARD, ReplayInputRouter.ACTION_INDICATOR_CLICK]:
		var kit := _kit_with_replay()
		var refusals: Array[int] = [0]
		assert_bool(ReplayInputRouter.route(kit.controller, action, func() -> void: refusals[0] += 1)).is_true()
		assert_bool(kit.controller.is_latched()).is_true()
		assert_int(refusals[0]).is_equal(0)
		assert_int(kit.battle.outcome_log.size()).is_equal(0)


func test_cancel_and_click_each_unlatch_while_latched() -> void:
	for action: StringName in [ReplayInputRouter.ACTION_CANCEL, ReplayInputRouter.ACTION_INDICATOR_CLICK]:
		var kit := _kit_with_replay()
		kit.controller.request_latch()
		var refusals: Array[int] = [0]
		assert_bool(ReplayInputRouter.route(kit.controller, action, func() -> void: refusals[0] += 1)).is_true()
		assert_bool(kit.controller.is_latched()).is_false()
		assert_int(refusals[0]).is_equal(0)


func test_press_that_changes_nothing_is_refused_exactly_once() -> void:
	var kit := _kit_with_replay()
	var refusals: Array[int] = [0]
	var refuse := func() -> void: refusals[0] += 1
	ReplayInputRouter.route(kit.controller, ReplayInputRouter.ACTION_CANCEL, refuse)  # cancel while unlatched
	assert_int(refusals[0]).is_equal(1)
	assert_bool(kit.controller.is_latched()).is_false()
	kit.controller.request_latch()
	ReplayInputRouter.route(kit.controller, ReplayInputRouter.ACTION_CONFIRM, refuse)  # confirm while latched
	assert_int(refusals[0]).is_equal(2)
	assert_bool(kit.controller.is_latched()).is_true()


func test_cancel_is_consumed_so_it_never_opens_the_menu() -> void:
	var kit := _kit_with_replay()
	assert_bool(ReplayInputRouter.route(kit.controller, ReplayInputRouter.ACTION_CANCEL, Callable())).is_true()
	assert_bool(ReplayInputRouter.route(kit.controller, &"menu", Callable())).is_false()


func test_only_knockout_holds_left_is_passive_and_refuses_every_press() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 999)
	kit.step(1)
	while kit.frames_of("beat_impact").is_empty():
		kit.step()
	assert_bool(kit.controller.is_press_effective()).is_false()
	assert_str(ReplayInputRouter.indicator_state(kit.controller)).is_equal(ReplayInputRouter.INDICATOR_PASSIVE)
	var refusals: Array[int] = [0]
	for action: StringName in [ReplayInputRouter.ACTION_CONFIRM, ReplayInputRouter.ACTION_FAST_FORWARD, ReplayInputRouter.ACTION_CANCEL, ReplayInputRouter.ACTION_INDICATOR_CLICK]:
		ReplayInputRouter.route(kit.controller, action, func() -> void: refusals[0] += 1)
	assert_int(refusals[0]).is_equal(4)
	assert_bool(kit.controller.is_latched()).is_false()


func test_takeover_full_is_passive_unless_speed_up_boss_on() -> void:
	for speed_up: bool in [false, true]:
		var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
		kit.controller.set_speed_settings(false, speed_up)
		kit.controller.enqueue_takeover(kit.enemies[0], BattleReplayController.HoldKind.TAKEOVER_FULL)
		kit.emit_turn(kit.squad[0])
		kit.step(2)
		assert_bool(kit.controller.is_replaying()).is_true()
		assert_bool(kit.controller.is_press_effective()).is_equal(speed_up)


func test_indicator_shows_on_every_replay_frame_and_passive_tracks_effective() -> void:
	var kit := _kit_with_replay()
	var changes: Array[int] = [0]
	kit.controller.press_effective_changed.connect(func(_e: bool) -> void: changes[0] += 1)
	var last_effective: bool = kit.controller.is_press_effective()
	while kit.controller.is_replaying():
		var state: StringName = ReplayInputRouter.indicator_state(kit.controller)
		assert_str(state).is_not_equal(ReplayInputRouter.INDICATOR_HIDDEN)
		assert_bool(state == ReplayInputRouter.INDICATOR_PASSIVE).is_equal(not kit.controller.is_press_effective())
		last_effective = kit.controller.is_press_effective()
		kit.step()
	assert_str(ReplayInputRouter.indicator_state(kit.controller)).is_equal(ReplayInputRouter.INDICATOR_HIDDEN)
	assert_int(changes[0]).is_greater(0)
	# After the replay the TURN is released with nothing submitted.
	assert_int(kit.frames_of("turn").size()).is_equal(1)
	assert_int(kit.battle.outcome_log.size()).is_equal(0)


func test_presses_while_gated_are_consumed_and_do_nothing() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), 0.3)
	kit.controller.enqueue_reveal_gate()
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	var refusals: Array[int] = [0]
	assert_bool(ReplayInputRouter.route(kit.controller, ReplayInputRouter.ACTION_CONFIRM, func() -> void: refusals[0] += 1)).is_true()
	assert_int(refusals[0]).is_equal(0)
	assert_bool(kit.controller.is_latched()).is_false()
