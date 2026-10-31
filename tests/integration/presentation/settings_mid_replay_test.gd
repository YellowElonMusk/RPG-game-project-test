## Story 056 (GDD sprite-camera-presentation AC-52; ADR-0006 §6, ADR-0009
## §7): the Battle mode's injected `PresentationSettings` view feeds
## `set_speed_settings()` on its `changed` signal. With a replay frozen by
## the Menu (no `advance()`) mid-wind-up, turning Faster battle animations
## On makes the wind-up play at `battle_speed_mult` from the next frame.
## With a frozen first-encounter takeover, turning Speed up boss entrances
## On makes it play at the plain-beat speed from the next frame, and the
## indicator turns active.
extends GdUnitTestSuite

const DT: float = BattleModeHarness.DT
const EPS: float = 1e-5


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness(is_boss: bool, settings: PresentationSettings) -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()), is_boss, settings)
	auto_free(h.mode)
	h.reveal()
	return h


func test_faster_battle_animations_applies_from_next_frame_after_freeze() -> void:
	var settings := PresentationSettings.new()
	var h := _harness(false, settings)
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var guard: int = 0
	while not menu.visible and guard < 3000:
		h.step()
		guard += 1
	h.press(InputActions.CONFIRM)
	h.press(InputActions.CONFIRM)
	h.step(3)
	var plan: BeatPlan = h.mode.replay.get_current_plan()
	assert_object(plan).is_not_null()
	assert_bool(plan.is_debug_path()).is_false()
	var p0: float = h.mode.replay.get_windup_progress()
	h.step()
	assert_float(h.mode.replay.get_windup_progress() - p0).is_equal_approx(DT, EPS)
	# The Menu freezes the mode: no advance() while the setting changes.
	var frozen: float = h.mode.replay.get_windup_progress()
	settings.faster_battle_animations = true
	assert_float(h.mode.replay.get_windup_progress()).is_equal(frozen)
	h.step()  # the Menu closes: the first frame after the freeze
	assert_float(h.mode.replay.get_windup_progress() - frozen).is_equal_approx(
			DT * h.mode.presentation_config.battle_speed_mult, EPS)


func test_speed_up_boss_entrances_applies_to_frozen_takeover_and_activates_indicator() -> void:
	var settings := PresentationSettings.new()
	settings.faster_battle_animations = true
	var h := _harness(true, settings)
	h.step(3)
	assert_array(h.frames_of("hold_started")).is_not_empty()
	var t0: float = h.mode.replay.get_hold_time()
	h.step()
	# Protected: 1x even with Faster battle animations On.
	assert_float(h.mode.replay.get_hold_time() - t0).is_equal_approx(DT, EPS)
	assert_str(String(ReplayInputRouter.indicator_state(h.mode.replay))).is_equal(
			String(ReplayInputRouter.INDICATOR_PASSIVE))
	var effective: Array[bool] = []
	h.mode.replay.press_effective_changed.connect(func(e: bool) -> void: effective.append(e))
	var frozen: float = h.mode.replay.get_hold_time()
	settings.speed_up_boss_entrances = true
	assert_array(effective).contains([true])
	assert_str(String(ReplayInputRouter.indicator_state(h.mode.replay))).is_equal(
			String(ReplayInputRouter.INDICATOR_ACTIVE))
	h.step()
	assert_float(h.mode.replay.get_hold_time() - frozen).is_equal_approx(
			DT * h.mode.presentation_config.battle_speed_mult, EPS)
