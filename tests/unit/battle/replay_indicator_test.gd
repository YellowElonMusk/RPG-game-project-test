## Story 074 (GDD sprite-camera-presentation rule 9 "Replay indicator",
## AC-38 text, AC-69; ADR-0008 §7/§12): the indicator shows the replay's
## three states with device glyphs, a click latches through the router, a
## refused press pulses the indicator, and its text clears 4.5:1 on its
## backing in every state.
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness() -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	return h


## Reveal, Attack, first target: the turn's replay is playing.
func _into_replay(h: BattleModeHarness) -> ReplayIndicator:
	h.reveal()
	h.press(InputActions.CONFIRM)
	h.press(InputActions.CONFIRM)
	h.mode.step_replay(0.0)
	return h.mode.replay_indicator()


func test_indicator_is_hidden_outside_a_replay() -> void:
	var h := _harness()
	var indicator: ReplayIndicator = h.mode.replay_indicator()
	assert_object(indicator).is_not_null()
	h.reveal()
	h.mode.step_replay(0.0)
	assert_bool(indicator.visible).override_failure_message("shown on the command menu").is_false()


func test_indicator_shows_active_then_latched_with_keyboard_glyphs() -> void:
	var h := _harness()
	var indicator: ReplayIndicator = _into_replay(h)
	assert_bool(indicator.visible).is_true()
	assert_str(indicator.current_state()).is_equal(ReplayInputRouter.INDICATOR_ACTIVE)
	assert_str(indicator.text_for(indicator.current_state())).is_equal("[Shift] Speed up")
	h.press(InputActions.CONFIRM)  # latches
	assert_str(indicator.current_state()).is_equal(ReplayInputRouter.INDICATOR_LATCHED)
	assert_str(indicator.text_for(indicator.current_state())).is_equal("Speeding up · [Escape] Stop")


func test_indicator_click_latches_and_unlatches_without_confirm() -> void:
	var h := _harness()
	var indicator: ReplayIndicator = _into_replay(h)
	indicator.indicator_clicked.emit()
	assert_str(indicator.current_state()).is_equal(ReplayInputRouter.INDICATOR_LATCHED)
	indicator.indicator_clicked.emit()
	assert_str(indicator.current_state()).is_equal(ReplayInputRouter.INDICATOR_ACTIVE)
	assert_int(h.mode.feedback.refusal_count).is_equal(0)


func test_refused_press_pulses_the_visible_indicator_once() -> void:
	var h := _harness()
	var indicator: ReplayIndicator = _into_replay(h)
	h.press(InputActions.CONFIRM)  # latches
	h.press(InputActions.CONFIRM)  # changes nothing: refused
	assert_int(h.mode.feedback.refusal_count).is_equal(1)
	assert_bool(indicator.offset_transform_enabled).override_failure_message(
			"no pulse on the indicator").is_true()
	await await_millis(40)
	assert_float(absf(indicator.offset_transform_position.x)).override_failure_message(
			"the pulse never moved the indicator").is_greater(0.0)


func test_gamepad_glyphs_follow_the_pad_style() -> void:
	var bindings: InputBindings = load(BattleMode.BINDINGS_PATH) as InputBindings
	var indicator: ReplayIndicator = auto_free(ReplayIndicator.new())
	indicator.glyphs = PromptGlyphs.new(bindings, PromptGlyphs.DEVICE_PAD, &"xbox")
	assert_str(indicator.text_for(ReplayInputRouter.INDICATOR_ACTIVE)).is_equal("[X] Speed up")
	assert_str(indicator.text_for(ReplayInputRouter.INDICATOR_LATCHED)).is_equal("Speeding up · [B] Stop")
	indicator.glyphs = PromptGlyphs.new(bindings, PromptGlyphs.DEVICE_PAD, &"playstation")
	assert_str(indicator.text_for(ReplayInputRouter.INDICATOR_ACTIVE)).is_equal("[Square] Speed up")


func test_indicator_is_not_focusable() -> void:
	var indicator: ReplayIndicator = auto_free(ReplayIndicator.new())
	assert_int(indicator.focus_mode).is_equal(Control.FOCUS_NONE)


func test_every_state_text_clears_aa_contrast_on_the_backing() -> void:
	for s: StringName in [ReplayInputRouter.INDICATOR_ACTIVE, ReplayInputRouter.INDICATOR_LATCHED,
			ReplayInputRouter.INDICATOR_PASSIVE]:
		var r: float = WcagContrast.ratio(ReplayIndicator.text_color_for(s), ReplayIndicator.COLOR_BACKING)
		assert_float(r).override_failure_message("%s text %.2f:1" % [s, r]).is_greater_equal(WcagContrast.AA_TEXT)


func test_refusal_pulse_is_zero_under_reduce_motion() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	var config := UiConfig.new()
	assert_object(RefusalPulse.play(button, config, true)).is_null()
	assert_vector(button.offset_transform_position).is_equal(Vector2.ZERO)
	assert_object(RefusalPulse.play(button, config, false)).is_not_null()


## Regression (story 074 capture): `reset_size()` kept the box's top-left,
## so a prompt longer than the empty box ran off the right edge of the
## screen ("[X] S" was all that showed at 1080p). The box grows left and up
## from its bottom-right corner, fully on screen.
func test_indicator_keeps_its_bottom_right_corner_with_its_longest_prompt() -> void:
	var h := _harness()
	var indicator: ReplayIndicator = _into_replay(h)
	h.press(InputActions.CONFIRM)  # latched: the longest prompt
	await await_idle_frame()
	var screen: Vector2 = indicator.get_viewport().get_visible_rect().size
	var corner: Vector2 = indicator.get_global_rect().end
	var expected: Vector2 = screen - Vector2.ONE * ReplayIndicator.MARGIN_PX
	assert_bool(corner.distance_to(expected) <= 1.0).override_failure_message(
			"indicator's corner %s, expected %s: a longer prompt pushes it off screen" % [corner, expected]).is_true()
