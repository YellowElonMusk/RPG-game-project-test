## Story 027 (GDD sprite-camera-presentation AC-23; ADR-0006 §4, §6, §9):
## `replay_time` holds across every speed, latch, floor, knockout and debug
## case. Driven headlessly against a stub `BattleCore` signal source with
## fixed 60 Hz `advance()` steps; every expected time is computed from the
## config through the formula, with one frame step allowed per event.
extends GdUnitTestSuite

const _TOL: float = 1e-4
const _WINDUP: float = 0.3


func _alt_config() -> PresentationConfig:
	var c := PresentationConfig.new()
	c.ff_mult = 2.5
	c.battle_speed_mult = 1.25
	c.beat_min = 0.5
	c.reaction_hold = 0.3
	c.ko_hold = 0.6
	c.follow_camera_dt_max = 0.05
	return c


## Asserts one beat's impact and end against the formula: impact at
## `w_wall`, end at `max(w_wall + hold, beat_min)`, hold never scaled.
func _assert_beat(kit: ReplayTestKit, plan: BeatPlan, w_wall: float, hold: float) -> void:
	var t: Dictionary = kit.beat_times(plan)
	var end_expected: float = maxf(w_wall + hold, kit.config.beat_min)
	assert_float(t["impact"]).is_between(w_wall - _TOL, w_wall + kit.h + _TOL)
	assert_float(t["end"]).is_between(end_expected - _TOL, end_expected + 2.0 * kit.h + _TOL)
	if w_wall + hold >= kit.config.beat_min:
		assert_float(t["end"] - t["impact"]).is_between(hold - _TOL, hold + kit.h + _TOL)


func _assert_each_once(kit: ReplayTestKit) -> void:
	for plan: BeatPlan in kit.plans():
		assert_int(kit.frames_of("beat_started", plan).size()).is_equal(1)
		assert_int(kit.frames_of("beat_impact", plan).size()).is_equal(1)
		assert_int(kit.frames_of("beat_finished", plan).size()).is_equal(1)
		assert_bool(kit.frames_of("beat_started", plan)[0] <= kit.frames_of("beat_impact", plan)[0]).is_true()
		assert_bool(kit.frames_of("beat_impact", plan)[0] < kit.frames_of("beat_finished", plan)[0]).is_true()


func _plain_replay(kit: ReplayTestKit) -> void:
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.emit_hit(kit.squad[1], kit.enemies[1], 5)
	kit.emit_turn(kit.squad[0])


func test_empty_replay_takes_no_time_and_emits_nothing() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), _WINDUP)
	kit.step(5)
	assert_int(kit.events.size()).is_equal(0)
	assert_bool(kit.controller.is_replaying()).is_false()


func test_plain_replay_unlatched_plays_every_windup_at_1x() -> void:
	for cfg: PresentationConfig in [PresentationConfig.new(), _alt_config()]:
		var kit := ReplayTestKit.new(cfg, _WINDUP)
		_plain_replay(kit)
		kit.run_until_idle()
		_assert_each_once(kit)
		for plan: BeatPlan in kit.plans():
			_assert_beat(kit, plan, _WINDUP, cfg.reaction_hold)
		var total: float = float(kit.frames_of("turn")[0] - kit.frames_of("replay_started")[0]) * kit.h
		var expected_total: float = 2.0 * maxf(_WINDUP + cfg.reaction_hold, cfg.beat_min)
		assert_float(total).is_between(expected_total - _TOL, expected_total + 4.0 * kit.h + _TOL)


func test_defend_has_no_hold_and_is_floored() -> void:
	var cfg := PresentationConfig.new()
	var kit := ReplayTestKit.new(cfg, _WINDUP)
	kit.emit_defend(kit.squad[0])
	kit.run_until_idle()
	var plan: BeatPlan = kit.plans()[0]
	assert_float(plan.hold).is_equal(0.0)
	_assert_beat(kit, plan, _WINDUP, 0.0)


func test_knockout_hold_is_max_of_ko_hold_and_landing() -> void:
	var cfg := PresentationConfig.new()
	for landing: float in [cfg.ko_hold - 0.3, cfg.ko_hold + 0.3]:
		var kit := ReplayTestKit.new(cfg, _WINDUP)
		kit.ko_landing_by_combatant[kit.enemies[0]] = landing
		kit.emit_hit(kit.squad[0], kit.enemies[0], 999)
		kit.run_until_idle()
		var plan: BeatPlan = kit.plans()[0]
		var hold: float = maxf(cfg.ko_hold, landing)
		assert_float(plan.hold).is_equal_approx(hold, _TOL)
		_assert_beat(kit, plan, _WINDUP, hold)


func test_knockout_windup_latched_plays_at_ff_mult_and_hold_unscaled() -> void:
	var cfg := PresentationConfig.new()
	var kit := ReplayTestKit.new(cfg, _WINDUP)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 999)
	assert_bool(kit.controller.request_latch()).is_true()
	kit.run_until_idle()
	_assert_beat(kit, kit.plans()[0], _WINDUP / cfg.ff_mult, cfg.ko_hold)


func test_latched_from_first_beat_plays_windups_at_ff_mult() -> void:
	for cfg: PresentationConfig in [PresentationConfig.new(), _alt_config()]:
		var kit := ReplayTestKit.new(cfg, _WINDUP)
		_plain_replay(kit)
		assert_bool(kit.controller.request_latch()).is_true()
		kit.run_until_idle()
		_assert_each_once(kit)
		for plan: BeatPlan in kit.plans():
			_assert_beat(kit, plan, _WINDUP / cfg.ff_mult, cfg.reaction_hold)


func test_latched_mid_beat_plays_rest_of_windup_at_ff_mult() -> void:
	var cfg := PresentationConfig.new()
	var kit := ReplayTestKit.new(cfg, 0.6)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.step(1)  # start frame: no time
	kit.step(10)
	var played: float = kit.controller.get_windup_progress()
	assert_float(played).is_equal_approx(10.0 * kit.h, _TOL)
	assert_bool(kit.controller.request_latch()).is_true()
	kit.run_until_idle()
	var w_wall: float = played + (0.6 - played) / cfg.ff_mult
	_assert_beat(kit, kit.plans()[0], w_wall, cfg.reaction_hold)


func test_latch_then_cancel_returns_windups_to_1x() -> void:
	var cfg := PresentationConfig.new()
	var kit := ReplayTestKit.new(cfg, _WINDUP)
	_plain_replay(kit)
	assert_bool(kit.controller.request_latch()).is_true()
	while kit.frames_of("beat_finished").size() < 1:
		kit.step()
	assert_bool(kit.controller.clear_latch()).is_true()
	kit.run_until_idle()
	var plans: Array[BeatPlan] = kit.plans()
	_assert_beat(kit, plans[0], _WINDUP / cfg.ff_mult, cfg.reaction_hold)
	_assert_beat(kit, plans[1], _WINDUP, cfg.reaction_hold)


func test_latch_clears_at_replay_end_so_next_replay_starts_unlatched() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), _WINDUP)
	_plain_replay(kit)
	kit.controller.request_latch()
	kit.run_until_idle()
	assert_bool(kit.controller.is_latched()).is_false()
	# The latch clears before the TURN marker is released.
	assert_bool(kit.events.find_custom(func(e: Dictionary) -> bool: return e["event"] == "latch_off")
			< kit.events.find_custom(func(e: Dictionary) -> bool: return e["event"] == "turn")).is_true()
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	assert_bool(kit.controller.is_latched()).is_false()


func test_faster_battle_animations_unlatched_and_latched() -> void:
	for cfg: PresentationConfig in [PresentationConfig.new(), _alt_config()]:
		var kit := ReplayTestKit.new(cfg, _WINDUP)
		kit.controller.set_speed_settings(true, false)
		_plain_replay(kit)
		kit.run_until_idle()
		_assert_beat(kit, kit.plans()[0], _WINDUP / cfg.battle_speed_mult, cfg.reaction_hold)
		var kit2 := ReplayTestKit.new(cfg, _WINDUP)
		kit2.controller.set_speed_settings(true, false)
		_plain_replay(kit2)
		kit2.controller.request_latch()
		kit2.run_until_idle()
		_assert_beat(kit2, kit2.plans()[0], _WINDUP / cfg.ff_mult, cfg.reaction_hold)


func test_beat_min_floor_pads_the_hold_not_the_impact() -> void:
	var cfg := PresentationConfig.new()
	var short_w: float = 0.05
	assert_bool(short_w + cfg.reaction_hold < cfg.beat_min).is_true()
	var kit := ReplayTestKit.new(cfg, short_w)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.run_until_idle()
	var t: Dictionary = kit.beat_times(kit.plans()[0])
	assert_float(t["impact"]).is_between(short_w - _TOL, short_w + kit.h + _TOL)
	assert_float(t["end"]).is_between(cfg.beat_min - _TOL, cfg.beat_min + 2.0 * kit.h + _TOL)


func test_debug_path_impacts_at_beat_min_minus_reaction_hold_at_every_speed() -> void:
	for cfg: PresentationConfig in [PresentationConfig.new(), _alt_config()]:
		for latched: bool in [false, true]:
			var kit := ReplayTestKit.new(cfg, -1.0)
			kit.controller.set_speed_settings(true, false)
			kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
			if latched:
				# The debug path is never press-effective: the latch is refused.
				assert_bool(kit.controller.request_latch()).is_false()
			kit.run_until_idle()
			var w: float = cfg.beat_min - cfg.reaction_hold
			_assert_beat(kit, kit.plans()[0], w, cfg.reaction_hold)


func test_ending_replay_clears_latch_before_battle_ended_after_replay() -> void:
	var kit := ReplayTestKit.new(PresentationConfig.new(), _WINDUP)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.battle.battle_ended.emit(true)
	kit.controller.request_latch()
	var latched_at_end: Array = [true]
	kit.controller.battle_ended_after_replay.connect(func(_w: bool) -> void:
		latched_at_end[0] = kit.controller.is_latched())
	kit.run_until_idle()
	assert_bool(latched_at_end[0]).is_false()
