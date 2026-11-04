## Faction Reputation & Endings (narrative bible §6.6, 2026-11-04): the
## ending follows the squad's lean, every shipped ending has a playable
## conversation, the credits roll and skip, and only an idle Overworld can
## finish the campaign.
extends GdUnitTestSuite


func _ws(cred: int, alien: int) -> WorldState:
	var ws := WorldState.new()
	ws.street_cred = cred
	ws.alien_points = alien
	return ws


func test_the_lean_picks_the_ending() -> void:
	assert_str(EndingRules.pick_id(_ws(3, 0))).is_equal(EndingRules.HUMAN)
	assert_str(EndingRules.pick_id(_ws(1, 2))).is_equal(EndingRules.ALIEN)
	assert_str(EndingRules.pick_id(_ws(2, 2))).is_equal(EndingRules.SPLIT)
	assert_str(EndingRules.pick_id(_ws(0, 0))).is_equal(EndingRules.SPLIT)


func test_every_ending_has_a_conversation_with_short_lines() -> void:
	for id: String in [EndingRules.HUMAN, EndingRules.ALIEN, EndingRules.SPLIT]:
		var ending: EndingData = EndingData.load_by_id(id)
		assert_object(ending).override_failure_message(id).is_not_null()
		assert_str(ending.id).is_equal(id)
		assert_str(ending.title).is_not_empty()
		var talk: Conversation = Conversation.load_by_id(ending.conversation_id)
		assert_object(talk).override_failure_message(ending.conversation_id).is_not_null()
		assert_bool(talk.lines.size() >= 3).is_true()
		for line: DialogueLine in talk.lines:
			# Narrative bible §9: every line fits the dialogue box.
			assert_bool(line.text.length() <= 120).override_failure_message(line.text).is_true()


func test_credits_show_the_ending_and_the_roll() -> void:
	var roll := CreditsRoll.new()
	roll.lines = PackedStringArray(["Thanks for playing."])
	var panel: CreditsPanel = auto_free(CreditsPanel.new())
	panel.setup(EndingData.load_by_id(EndingRules.ALIEN), roll)
	assert_str(panel.text()).contains("Ending: Another Chance")
	assert_str(panel.text()).contains("Thanks for playing.")


func test_credits_skip_only_after_the_guard() -> void:
	var roll := CreditsRoll.new()
	roll.skip_guard_s = 1.0
	var panel: CreditsPanel = auto_free(CreditsPanel.new())
	panel.setup(null, roll)
	var finished: Array[int] = [0]
	panel.finished.connect(func() -> void: finished[0] += 1)
	panel.handle_action(InputActions.CONFIRM, true)
	assert_int(finished[0]).is_equal(0)
	panel.advance(1.0)
	panel.handle_action(InputActions.CONFIRM, true)
	panel.handle_action(InputActions.CANCEL, true)
	assert_int(finished[0]).is_equal(1)
	assert_bool(panel.is_done()).is_true()


func test_credits_end_by_themselves() -> void:
	var roll := CreditsRoll.new()
	roll.lines = PackedStringArray(["a", "b"])
	roll.scroll_px_per_s = 400.0
	var panel: CreditsPanel = auto_free(CreditsPanel.new())
	panel.setup(null, roll)
	var finished: Array[int] = [0]
	panel.finished.connect(func() -> void: finished[0] += 1)
	for i: int in 600:
		panel.advance(1.0 / 60.0)
	assert_int(finished[0]).is_equal(1)


func test_shipped_credits_roll_loads() -> void:
	assert_bool(CreditsRoll.load_default().lines.size() > 0).is_true()


func test_finish_campaign_goes_to_title_from_an_idle_overworld() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var payload := CreditsPayload.new()
	assert_int(machine.finish_campaign(payload)).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(machine.finish_campaign(payload)).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)


func test_finish_campaign_waits_for_overlays_to_close() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE, DialogueLinePayload.new("hi"))
	assert_int(machine.finish_campaign(CreditsPayload.new())).is_equal(
			GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	machine.close_overlay()
	assert_int(machine.finish_campaign(CreditsPayload.new())).is_equal(GameStateMachine.RequestResult.OK)


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message("transition did not finish").is_true()
