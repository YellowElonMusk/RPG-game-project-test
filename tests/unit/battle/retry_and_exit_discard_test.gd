## Story 040 (GDD sprite-camera-presentation AC-36; ADR-0006 §5, §8): a
## stub battle emits 5 outcomes and a turn (or an END), played through 2
## beats, then Retry, Retreat or Quit discards the rest. No beat, number or
## released-marker event fires for a discarded entry; Retry cancels at
## `transition_started(BATTLE, BATTLE)` and again in
## `restore_start_snapshot()`, and its `display_resynced` resets the display
## (numbers cleared, every sprite `idle`, punch 0, indicator hidden) to the
## restored party and full-reset enemy values; an exit plays no Victory or
## Defeat light afterwards. On every path, on the next frame, the punch is
## 0, the latch is clear and no beat-driven animation advances.
extends GdUnitTestSuite

const DISCARDED_EVENTS: Array[String] = ["beat_started", "beat_impact", "beat_finished", "round", "end"]


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness() -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	h.reveal()
	assert_int(h.mode.replay.get_state()).is_equal(BattleReplayController.State.IDLE)
	return h


## Five outcomes (the first knocks a squad member out) and a turn, or an END
## when `end_marker`; plays until two beats have finished.
func _queue_five_and_play_two(h: BattleModeHarness, end_marker: bool = false) -> void:
	var s: Array[Combatant] = h.mode.battle.squad
	var e: Combatant = h.mode.battle.enemies[0]
	h.emit_hit(e, s[0], 999)
	h.emit_hit(s[1], e, 3)
	h.emit_hit(s[2], e, 3)
	h.emit_hit(s[3], e, 3)
	h.emit_hit(e, s[1], 2)
	if end_marker:
		h.mode.battle.battle_ended.emit(false)
	else:
		h.mode.battle.turn_started.emit(s[0])
	var guard: int = 0
	while h.frames_of("beat_finished").size() < 2 and guard < 2000:
		h.step()
		guard += 1
	assert_int(h.frames_of("beat_finished").size()).is_equal(2)
	assert_bool(h.mode.replay.is_replaying()).is_true()


func _assert_no_discarded_events(h: BattleModeHarness, mark: int) -> void:
	var since: Array[String] = h.event_names_since(mark)
	for event_name: String in DISCARDED_EVENTS:
		assert_bool(since.has(event_name)).override_failure_message(
				"%s fired for a discarded entry: %s" % [event_name, since]).is_false()


func _assert_next_frame_clean(h: BattleModeHarness) -> void:
	h.step()
	assert_vector(Vector2(h.stage.punch_offset_px())).is_equal(Vector2.ZERO)
	assert_bool(h.mode.replay.is_latched()).is_false()
	assert_object(h.mode.replay.get_current_plan()).is_null()


func _assert_no_end_light_since(h: BattleModeHarness, from: int) -> void:
	for i: int in range(from, h.profile_requests.size()):
		assert_bool(h.profile_requests[i] in [&"victory", &"defeat"]).override_failure_message(
				"%s light played after leaving the battle" % h.profile_requests[i]).is_false()


## What `display_resynced`'s listeners left on screen, read at emission.
func _snapshot_reset(h: BattleModeHarness, out: Dictionary) -> void:
	var hud: BattleHud = h.mode.get_node(^"%BattleHud")
	var view: BattleView = h.mode.get_node(^"%BattleView")
	out["numbers"] = hud.number_count()
	var not_idle: Array[String] = []
	for c: Combatant in h.mode.battle.squad + h.mode.battle.enemies:
		var sprite: CharacterSprite = view.get_sprite(c)
		if sprite != null and not String(sprite.animation).begins_with("idle"):
			not_idle.append("%s:%s" % [c.display_name, sprite.animation])
	out["not_idle"] = not_idle
	out["punch"] = h.stage.punch_offset_px()
	out["indicator"] = ReplayInputRouter.indicator_state(h.mode.replay)


func test_retry_mid_replay_discards_queue_and_resets_display() -> void:
	var h := _harness()
	var squad: Array[Combatant] = h.mode.battle.squad
	var start_hp: Array[int] = []
	var start_mp: Array[int] = []
	for c: Combatant in squad:
		start_hp.append(c.hp)
		start_mp.append(c.mp)
	_queue_five_and_play_two(h)
	var view: BattleView = h.mode.get_node(^"%BattleView")
	view.present()
	assert_str(String(view.get_sprite(squad[0]).animation)).starts_with("knockout")
	var cancels: int = h.mode.replay.cancel_calls
	var mark: int = h.events.size()
	var reset: Dictionary = {}
	h.mode.replay.display_resynced.connect(_snapshot_reset.bind(h, reset))
	assert_int(h.machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_int(h.machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	# Cancelled at transition_started(BATTLE, BATTLE), before the flash plays.
	assert_int(h.mode.replay.cancel_calls).override_failure_message(
			"no cancel when the retry transition started").is_equal(cancels + 1)
	assert_int(h.mode.replay.get_state()).is_equal(BattleReplayController.State.IDLE)
	assert_bool(h.mode.is_presenting()).is_false()
	h.run_machine_to_idle()
	# And again, unconditionally, first thing in restore_start_snapshot().
	assert_int(h.mode.replay.cancel_calls).is_equal(cancels + 2)
	assert_bool(reset.is_empty()).override_failure_message("display_resynced never fired").is_false()
	assert_int(int(reset["numbers"])).override_failure_message("numbers left after Retry").is_equal(0)
	assert_array(reset["not_idle"]).is_empty()
	assert_vector(Vector2(reset["punch"])).is_equal(Vector2.ZERO)
	assert_str(String(reset["indicator"])).is_equal(String(ReplayInputRouter.INDICATOR_HIDDEN))
	_assert_no_discarded_events(h, mark)
	var since: Array[String] = h.event_names_since(mark)
	# The one released turn is the retried fight's own first turn, after the
	# resync; the discarded queue's turn never fires.
	assert_int(since.count("turn")).is_equal(1)
	assert_int(since.find("turn")).is_greater(since.find("display_resynced"))
	for i: int in squad.size():
		assert_int(h.mode.replay.get_display(squad[i]).hp).is_equal(start_hp[i])
		assert_int(h.mode.replay.get_display(squad[i]).mp).is_equal(start_mp[i])
	for e: Combatant in h.mode.battle.enemies:
		assert_int(h.mode.replay.get_display(e).hp).is_equal(e.max_hp)
	_assert_next_frame_clean(h)


func test_quit_mid_replay_discards_and_plays_no_end_light() -> void:
	var h := _harness()
	_queue_five_and_play_two(h, true)
	var mark: int = h.events.size()
	var lights: int = h.profile_requests.size()
	assert_int(h.machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_int(h.machine.request_transition(GameStateMachine.Mode.TITLE)).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_int(h.mode.replay.get_state()).is_equal(BattleReplayController.State.IDLE)
	h.run_machine_to_idle()
	h.step(600)
	_assert_no_discarded_events(h, mark)
	_assert_no_end_light_since(h, lights)
	assert_int(h.pending_outcome()).is_equal(-1)
	_assert_next_frame_clean(h)


func test_retreat_mid_replay_discards_and_plays_no_end_light() -> void:
	var h := _harness()
	_queue_five_and_play_two(h, true)
	var mark: int = h.events.size()
	var lights: int = h.profile_requests.size()
	h.machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
	assert_int(h.machine.choose_retreat()).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(h.mode.replay.get_state()).is_equal(BattleReplayController.State.IDLE)
	h.run_machine_to_idle()
	h.step(600)
	_assert_no_discarded_events(h, mark)
	_assert_no_end_light_since(h, lights)
	_assert_next_frame_clean(h)


func test_quit_mid_hold_cancels_hold_and_never_reports() -> void:
	var h := _harness()
	_queue_five_and_play_two(h, true)
	var guard: int = 0
	while h.frames_of("end").is_empty() and guard < 3000:
		h.step()
		guard += 1
	assert_bool(h.mode.is_presenting()).override_failure_message("no end-of-fight hold").is_true()
	var lights: int = h.profile_requests.size()
	h.machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())
	assert_int(h.machine.request_transition(GameStateMachine.Mode.TITLE)).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_bool(h.mode.is_presenting()).override_failure_message("hold still running").is_false()
	h.run_machine_to_idle()
	h.step(600)
	assert_int(h.pending_outcome()).is_equal(-1)
	for entry: Dictionary in h.game_log.entries:
		assert_str(String(entry.get("code", ""))).is_not_equal("outcome_during_transition")
	_assert_no_end_light_since(h, lights)
	_assert_next_frame_clean(h)
