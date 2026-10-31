## Story 049 (GDD sprite-camera-presentation AC-45, rule 6; ADR-0006 §2,
## §5, §6; ADR-0005 §3). In a boss fight run by the real Battle mode over a
## real, seeded `BattleCore`, the replay controller and a real
## `GameStateMachine` (`BattleModeHarness`):
## - **Starts on reveal:** no boss light and no hold clock before the reveal
##   gate opens; the takeover starts on the reveal frame and its blend has
##   moved on the next frame.
## - **First encounter, protected:** with Speed up boss entrances Off it lasts
##   `blend_boss + boss_hold` (within one frame) with Faster battle
##   animations On and a press made (the press is refused: nothing speeds a
##   protected takeover). With it On: `/ battle_speed_mult` with Faster battle
##   animations On and no press, `/ ff_mult` latched.
## - **One clock:** every takeover frame, the stage's blend equals
##   `smoothstep(clamp(t_hold / blend_boss, 0, 1))` within 1e-4 and the boss
##   shows its `intro` at `t_hold - blend_boss` (frame 0 before that), with
##   `t_hold` the controller's `get_hold_time()`.
## - **Holds the battle:** no beat starts and no command menu opens before
##   `hold_finished`.
## - **Retry settles:** `boss_retry_hold` at 1x, `/ battle_speed_mult` with
##   Faster battle animations On, `/ ff_mult` latched; the boss holds the
##   last frame of its `intro` throughout.
extends GdUnitTestSuite

const DT: float = BattleModeHarness.DT
const TOL: float = 1e-4
const BOSS_PROFILE: StringName = &"boss_bureaucratia"


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


# --- Fixture -----------------------------------------------------------------

func _settings(faster: bool, speed_up_boss: bool) -> PresentationSettings:
	var s := PresentationSettings.new()
	s.faster_battle_animations = faster
	s.speed_up_boss_entrances = speed_up_boss
	return s


## A boss harness stopped just before the reveal.
func _harness(settings: PresentationSettings = null) -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()), true, settings)
	auto_free(h.mode)
	return h


func _view(h: BattleModeHarness) -> BattleView:
	return h.mode.get_node(^"%BattleView") as BattleView


func _boss(h: BattleModeHarness) -> Combatant:
	return h.mode.replay.get_boss_combatant()


## The boss's front `intro` animation (rule 10: required for a boss set).
func _intro(h: BattleModeHarness) -> SpriteAnimationData:
	var sets: Dictionary = _view(h).get(&"_sets")
	return (sets[_boss(h)] as SpriteSetData).find(SpriteSetData.INTRO, BattleView.ENEMY_FACING)


## Ticks the machine and mode time together until IDLE (the reveal).
func _reveal(h: BattleModeHarness) -> void:
	h.reveal()


## The "one clock" checks for this frame (call after a step).
func _assert_one_clock(h: BattleModeHarness) -> void:
	var r: BattleReplayController = h.mode.replay
	if not r.is_holding():
		return
	var cfg: PresentationConfig = h.mode.presentation_config
	var t_hold: float = r.get_hold_time()
	_view(h).present()
	var sprite: CharacterSprite = _view(h).get_sprite(_boss(h))
	var intro: SpriteAnimationData = _intro(h)
	assert_str(String(sprite.animation)).override_failure_message(
			"the boss is not on its intro during the takeover (t_hold %.3f)" % t_hold).is_equal(
			"%s_%s" % [SpriteSetData.INTRO, BattleView.ENEMY_FACING])
	if r.get_hold_kind() == BattleReplayController.HoldKind.TAKEOVER_SETTLE:
		assert_int(sprite.frame).override_failure_message("the settle is not on the intro's last frame") \
				.is_equal(intro.frame_count() - 1)
		return
	var expected_p: float = smoothstep(0.0, 1.0, clampf(t_hold / cfg.blend_boss, 0.0, 1.0))
	assert_float(absf(h.stage.blend_p() - expected_p)).override_failure_message(
			"blend %.5f vs smoothstep(t_hold / blend_boss) %.5f at t_hold %.4f" % [
			h.stage.blend_p(), expected_p, t_hold]).is_less_equal(TOL)
	assert_int(sprite.frame).override_failure_message("intro frame off the hold clock at t_hold %.4f" % t_hold) \
			.is_equal(BattleView.frame_at(intro, maxf(0.0, t_hold - cfg.blend_boss)))


## Steps until `hold_finished`, checking one clock and holding every frame;
## presses CONFIRM on the takeover's first frame when `press`. Returns the
## takeover's length in seconds (frames from hold_started to hold_finished).
func _play_takeover(h: BattleModeHarness, press: bool) -> float:
	var finished_before: int = h.frames_of("hold_finished").size()
	var guard: int = 0
	while h.frames_of("hold_started").size() <= finished_before and guard < 600:
		h.step()
		guard += 1
	var started: int = h.frames_of("hold_started")[-1]
	if press:
		h.press(InputActions.CONFIRM)
	_assert_one_clock(h)
	guard = 0
	while h.frames_of("hold_finished").size() <= finished_before and guard < 3000:
		h.step()
		_assert_one_clock(h)
		guard += 1
	var finished: int = h.frames_of("hold_finished")[-1]
	return float(finished - started) * DT


## Plays the takeover, loses, and plays the Defeat hold; the prompt is open.
func _lose(h: BattleModeHarness) -> void:
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var guard: int = 0
	while not menu.visible and guard < 3000:
		h.step()
		guard += 1
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.DEFEAT)
	guard = 0
	while h.pending_outcome() == -1 and guard < 3000:
		h.step()
		guard += 1
	assert_int(h.pending_outcome()).is_equal(GameStateMachine.BattleResult.DEFEAT)


## Retries and returns the settle's length in seconds.
func _retry_settle(h: BattleModeHarness, press: bool) -> float:
	_lose(h)
	assert_int(h.machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	h.run_machine_to_idle()
	return _play_takeover(h, press)


func _assert_within_frame(actual: float, expected: float, what: String) -> void:
	assert_float(absf(actual - expected)).override_failure_message(
			"%s lasted %.4fs, expected %.4fs" % [what, actual, expected]).is_less_equal(DT + 1e-6)


# --- Tests -------------------------------------------------------------------

func test_takeover_starts_on_the_reveal_frame_and_not_before() -> void:
	var h := _harness()
	var r: BattleReplayController = h.mode.replay
	var reveal_frame: int = -1
	var ticks: int = 0
	while h.machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		h.machine.tick(DT)
		var gated: bool = r.get_state() == BattleReplayController.State.GATED
		h.step()
		if gated:
			# Before the reveal: no hold clock and no boss light at all.
			if r.get_state() == BattleReplayController.State.GATED:
				assert_float(r.get_hold_time()).is_equal(0.0)
				assert_bool(h.profile_requests.has(BOSS_PROFILE)).override_failure_message(
						"boss light requested before the reveal").is_false()
		if reveal_frame < 0 and r.get_state() != BattleReplayController.State.GATED:
			reveal_frame = h.frame
		ticks += 1
	assert_int(reveal_frame).is_greater(0)
	assert_array(h.frames_of("hold_started")).contains_exactly([reveal_frame])
	assert_bool(h.profile_requests.has(BOSS_PROFILE)).is_true()
	assert_float(h.stage.blend_p()).is_equal(0.0)
	h.step()
	assert_float(h.stage.blend_p()).override_failure_message(
			"the takeover blend has not started on the frame after the reveal").is_greater(0.0)


func test_protected_takeover_lasts_full_length_with_faster_animations_and_a_press() -> void:
	var h := _harness(_settings(true, false))
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	var length: float = _play_takeover(h, true)
	assert_bool(h.mode.replay.is_latched()).is_false()
	_assert_within_frame(length, cfg.blend_boss + cfg.boss_hold, "protected takeover")


func test_sped_up_takeover_lasts_over_battle_speed_mult_without_a_press() -> void:
	var h := _harness(_settings(true, true))
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	var length: float = _play_takeover(h, false)
	_assert_within_frame(length, (cfg.blend_boss + cfg.boss_hold) / cfg.battle_speed_mult,
			"sped-up takeover, Faster battle animations On")


func test_sped_up_takeover_lasts_over_ff_mult_when_latched() -> void:
	var h := _harness(_settings(false, true))
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	var length: float = _play_takeover(h, true)
	_assert_within_frame(length, (cfg.blend_boss + cfg.boss_hold) / cfg.ff_mult, "latched sped-up takeover")


func test_takeover_holds_every_beat_and_the_command_menu() -> void:
	var h := _harness()
	_reveal(h)
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var finished_before: int = h.frames_of("hold_finished").size()
	var guard: int = 0
	while h.frames_of("hold_finished").size() == finished_before and guard < 3000:
		assert_bool(menu.visible).override_failure_message("command menu open during the takeover").is_false()
		h.step()
		guard += 1
	var hold_end: int = h.frames_of("hold_finished")[0]
	for f: int in h.frames_of("beat_started") + h.frames_of("turn"):
		assert_int(f).override_failure_message("a beat or turn released before the takeover ended") \
				.is_greater_equal(hold_end)
	assert_array(h.frames_of("turn")).is_not_empty()


func test_retry_settle_lasts_boss_retry_hold_at_1x() -> void:
	var h := _harness()
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	_assert_within_frame(_retry_settle(h, false), cfg.boss_retry_hold, "settle at 1x")


func test_retry_settle_lasts_over_battle_speed_mult_with_faster_animations() -> void:
	var h := _harness(_settings(true, false))
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	_assert_within_frame(_retry_settle(h, false), cfg.boss_retry_hold / cfg.battle_speed_mult,
			"settle, Faster battle animations On")


func test_retry_settle_lasts_over_ff_mult_when_latched() -> void:
	var h := _harness()
	_reveal(h)
	var cfg: PresentationConfig = h.mode.presentation_config
	_assert_within_frame(_retry_settle(h, true), cfg.boss_retry_hold / cfg.ff_mult, "latched settle")
