## Story 015 (GDD sprite-camera-presentation AC-13; ADR-0006 §1/§4): a real,
## seeded `BattleCore` drives `BattleReplayController`, played unlatched,
## latched and with Faster battle animations On. Beats play in log order;
## impact lands on the first frame the wind-up reaches `w_i` (from the action
## animation's `impact_frame`); the end comes `hold_i` after impact or at the
## `beat_min` floor; no number shows before the end; frames follow the
## wind-up and (unscaled) post-impact clocks; a Defend-then-Attack enemy turn
## runs back to back; the debug path impacts at `beat_min - reaction_hold`.
extends GdUnitTestSuite

const H: float = 1.0 / 60.0
const EPS: float = 1e-6
## Fixture action animation: 12 fps, 8 frames, impact on frame 4.
const FPS: float = 12.0
const FRAME_COUNT: int = 8
const IMPACT_FRAME: int = 4
const SEED: int = 15

var _config: PresentationConfig
var _battle: BattleCore
var _controller: BattleReplayController
var _squad: Array[Combatant] = []
var _enemies: Array[Combatant] = []
## Box: the frame counter, read by the signal recorders.
var _frame: Array[int] = [0]
var _events: Array[Dictionary] = []
## One entry per frame: {"frame", "plan", "windup", "post", "hp": Combatant -> int}.
var _samples: Array[Dictionary] = []


class _TurnRule extends FactionRule:
	## Each enemy turn's actions: Array of Array of {"move", "target_index"}.
	var turns: Array = []
	var _cursor: int = 0

	func specials_allowed(_round_number: int) -> bool:
		return true

	func move_allowed(_actor: Combatant, _move: Move) -> bool:
		return true

	func choose_enemy_action(_enemy: Combatant, living_squad: Array[Combatant],
			_round_number: int, _rng: RandomNumberGenerator) -> Array:
		if _cursor >= turns.size():
			return []
		var turn: Array = turns[_cursor]
		_cursor += 1
		var out: Array = []
		for a: Dictionary in turn:
			out.append({"move": a["move"], "target": living_squad[a["target_index"]]})
		return out


func after_test() -> void:
	if _controller != null:
		_controller.dispose()
	_controller = null
	_battle = null
	_events.clear()
	_samples.clear()
	_frame[0] = 0


func _make_config(alt: bool) -> PresentationConfig:
	var c := PresentationConfig.new()
	if alt:
		c.reaction_hold = 0.22
		c.beat_min = 0.48
		c.ko_hold = 0.55
		c.ff_mult = 2.4
		c.battle_speed_mult = 1.6
	return c


func _windup_from_animation(_p: BeatPlan) -> float:
	return BeatPlan.windup_for(IMPACT_FRAME, FPS)


func _no_animation(_p: BeatPlan) -> float:
	return -1.0


func _no_ko_landing(_c: Combatant) -> float:
	return 0.0


func _record(event_name: String, plan: BeatPlan) -> void:
	_events.append({"event": event_name, "plan": plan, "frame": _frame[0]})


## Plays S1 -> E1, S2 -> E2 (a knockout), then E1's Defend-then-Attack turn,
## until the round-2 command menu would open. `mode`: plain, latched or fast.
func _play(mode: String, alt: bool, windup: Callable) -> void:
	_config = _make_config(alt)
	assert_array(Array(_config.validate())).is_empty()
	_squad = [Combatant.new("S1", 40, 10, 10, 5, 10, false), Combatant.new("S2", 40, 10, 10, 5, 9, false)]
	_enemies = [Combatant.new("E1", 40, 10, 10, 5, 8, true), Combatant.new("E2", 40, 10, 10, 5, 7, true)]
	var rule := _TurnRule.new()
	rule.turns = [[{"move": Move.make_defend(), "target_index": 0},
			{"move": Move.make_attack(), "target_index": 0}]]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_battle = BattleCore.new(_squad, _enemies, rng, rule)
	_controller = BattleReplayController.new(_battle, windup, _no_ko_landing, _config)
	_controller.set_speed_settings(mode == "fast", false)
	_controller.beat_started.connect(func(p: BeatPlan) -> void: _record("start", p))
	_controller.beat_impact.connect(func(p: BeatPlan) -> void: _record("impact", p))
	_controller.beat_finished.connect(func(p: BeatPlan) -> void: _record("end", p))
	var pending: Array = [null]
	_controller.turn_started_after_replay.connect(func(c: Combatant) -> void: pending[0] = c)
	_battle.start_battle(false)
	BattleContentSeam.arrange_vitals(_enemies[1], 1, 0)
	_controller.resync()
	var targets: Array[Combatant] = [_enemies[0], _enemies[1]]
	var submitted: int = 0
	for guard: int in 4000:
		if pending[0] != null:
			if submitted == targets.size():
				break
			pending[0] = null
			_battle.submit_action(Move.make_attack(), targets[submitted])
			submitted += 1
			if mode == "latched":
				_controller.request_latch()
		_frame[0] += 1
		_controller.advance(H)
		var hp: Dictionary = {}
		for c: Combatant in _squad + _enemies:
			hp[c] = _controller.get_display_hp(c)
		_samples.append({"frame": _frame[0], "plan": _controller.get_current_plan(),
				"windup": _controller.get_windup_progress(),
				"post": _controller.get_post_impact_time(), "hp": hp})


func _frames(event_name: String, plan: BeatPlan) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in _events:
		if e["event"] == event_name and e["plan"] == plan:
			out.append(int(e["frame"]))
	return out


func _plans() -> Array[BeatPlan]:
	var out: Array[BeatPlan] = []
	for e: Dictionary in _events:
		if e["event"] == "start":
			out.append(e["plan"])
	return out


func _sample(f: int) -> Dictionary:
	return _samples[f - 1]


func _speed(mode: String) -> float:
	match mode:
		"latched":
			return _config.ff_mult
		"fast":
			return _config.battle_speed_mult
	return 1.0


## Frames from start to impact: the first n with n * h * speed >= w - EPS.
func _impact_n(w: float, speed: float) -> int:
	return maxi(ceili((w - EPS) / (H * speed)), 0)


func test_replay_order_impact_end_and_clocks(mode: String, alt: bool, test_parameters := [
		["plain", false], ["latched", false], ["fast", false],
		["plain", true], ["latched", true], ["fast", true]]) -> void:
	_play(mode, alt, _windup_from_animation)
	var plans := _plans()
	var w: float = BeatPlan.windup_for(IMPACT_FRAME, FPS)
	var speed: float = _speed(mode)
	# order: one beat per log entry, in log order, start < impact < end, once each.
	assert_int(plans.size()).is_equal(_battle.outcome_log.size())
	assert_int(plans.size()).is_equal(4)
	var prev_end: int = 0
	for i: int in plans.size():
		var p: BeatPlan = plans[i]
		assert_object(p.outcome).is_same(_battle.outcome_log[i])
		assert_array(_frames("start", p)).has_size(1)
		assert_array(_frames("impact", p)).has_size(1)
		assert_array(_frames("end", p)).has_size(1)
		var s: int = _frames("start", p)[0]
		var k: int = _frames("impact", p)[0]
		var e: int = _frames("end", p)[0]
		assert_int(s).is_greater_equal(prev_end)
		prev_end = e
		# impact: the first frame the wind-up reaches w_i.
		assert_int(k - s).is_equal(_impact_n(w, speed))
		assert_int(BeatPlan.frame_at(_sample(k)["windup"], FPS, FRAME_COUNT)).is_equal(IMPACT_FRAME)
		# end: hold_i of 1x time after impact, or the beat_min floor.
		var expected_end: int = maxi(maxi(k + ceili((p.hold - EPS) / H), s + ceili((_config.beat_min - EPS) / H)), k + 1)
		assert_int(e).is_equal(expected_end)
		for f: int in range(s + 1, e):
			var smp: Dictionary = _sample(f)
			assert_object(smp["plan"]).is_same(p)
			# No number shows before the end: displayed HP is the pre-beat value.
			for c: Combatant in p.hp_changes.keys():
				assert_int(int(smp["hp"][c])).is_equal(int(_sample(s)["hp"][c]))
			if f < k:
				# frames: the actor follows the wind-up clock.
				assert_float(float(smp["windup"])).is_equal_approx(float(f - s) * H * speed, 1e-5)
				assert_int(BeatPlan.frame_at(smp["windup"], FPS, FRAME_COUNT)).is_less(IMPACT_FRAME)
			elif f > k:
				# frames: reactions follow the unscaled post-impact clock.
				assert_float(float(smp["post"])).is_equal_approx(float(f - k) * H, 1e-5)
		# At the end the displayed state is the beat's snapshot.
		for c: Combatant in p.hp_changes.keys():
			assert_int(int(_sample(e)["hp"][c]) - int(_sample(s)["hp"][c])).is_equal(int(p.hp_changes[c]))
	# The knockout beat holds ko_hold; an animation that has run out shows its last frame.
	assert_bool(plans[1].knockout).is_true()
	assert_float(plans[1].hold).is_equal_approx(_config.ko_hold, EPS)
	assert_int(BeatPlan.frame_at(_config.ko_hold * 10.0, FPS, FRAME_COUNT)).is_equal(FRAME_COUNT - 1)


func test_back_to_back_enemy_defend_then_attack_no_idle_between(mode: String, test_parameters := [
		["plain"], ["latched"], ["fast"]]) -> void:
	_play(mode, false, _windup_from_animation)
	var plans := _plans()
	var defend: BeatPlan = plans[2]
	var attack: BeatPlan = plans[3]
	assert_object(attack.actor).is_same(defend.actor)
	assert_int(defend.action_role).is_equal(BeatPlan.ActionRole.DEFEND)
	var f: int = _frames("start", attack)[0]
	# The second beat starts on the frame the first ends: no idle frame between.
	assert_int(f).is_equal(_frames("end", defend)[0])
	assert_object(_sample(f)["plan"]).is_same(attack)
	assert_str(String(attack.action_animation(func(_k: StringName) -> bool: return false))).is_equal("attack")
	assert_int(BeatPlan.frame_at(_sample(f)["windup"], FPS, FRAME_COUNT)).is_equal(0)


func test_debug_path_impacts_at_beat_min_minus_reaction_hold(mode: String, alt: bool, test_parameters := [
		["plain", false], ["latched", false], ["fast", false], ["plain", true], ["fast", true]]) -> void:
	_play(mode, alt, _no_animation)
	var plans := _plans()
	assert_int(plans.size()).is_equal(4)
	var n: int = _impact_n(_config.beat_min - _config.reaction_hold, 1.0)
	for p: BeatPlan in plans:
		assert_bool(p.is_debug_path()).is_true()
		assert_int(_frames("impact", p)[0] - _frames("start", p)[0]).is_equal(n)
