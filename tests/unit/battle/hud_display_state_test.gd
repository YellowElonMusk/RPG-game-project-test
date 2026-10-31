## Story 070 (GDD sprite-camera-presentation AC-65; ADR-0006 §2, §4): with
## the AC-14b moves (Attack, Defend, Family Meal, Speak to the Manager)
## resolved by a real, seeded `BattleCore` under MegaCorp's billing rule and
## replayed through the real `BattleHud`:
## - each beat's numbers (`BeatPlan.numbers()`, AC-14b) appear over their own
##   combatants on the frame the beat ends, and none before it;
## - on every frame the HUD's HP and MP stay at the last released snapshot
##   until a beat finishes or a marker is released;
## - MegaCorp's per-round MP bill and the new round number appear on the
##   frame the ROUND marker is released, not before.
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0

var _battle: BattleCore
var _controller: BattleReplayController
var _hud: BattleHud
## Set by the release listeners; cleared before each frame.
var _released: Array[bool] = [false]
var _failures: Array[String] = []
## Rounds released, and whether a squad member's shown MP dropped on one.
var _round_releases: Array[int] = []
var _billed_on_release: Array[bool] = [false]
var _numbers_checked: Array[int] = [0]
## HUD values at the most recent release.
var _last_release: Array = []


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	if _controller != null:
		_controller.dispose()
	_controller = null
	_battle = null
	_hud = null
	_failures.clear()
	_round_releases.clear()


func _member(block: Dictionary) -> Combatant:
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


func _windup(_p: BeatPlan) -> float:
	return 0.3


func _ko(_c: Combatant) -> float:
	return 0.0


func _hud_values() -> Array:
	var out: Array = [_hud.shown_round()]
	for c: Combatant in _battle.squad + _battle.enemies:
		var v: Dictionary = _hud.card_values(c)
		out.append([v["hp"], v["mp"]])
	return out


func _on_beat_finished(plan: BeatPlan) -> void:
	_released[0] = true
	_last_release = _hud_values()
	var numbers: Dictionary = plan.numbers()
	for c: Combatant in numbers.keys():
		_numbers_checked[0] += 1
		if _hud.number_over(c) != String(numbers[c]):
			_failures.append("beat end: %s shows '%s', plan says '%s'" % [
					c.display_name, _hud.number_over(c), numbers[c]])
	for c: Combatant in _battle.squad + _battle.enemies:
		if not numbers.has(c) and plan.hp_changes.has(c):
			_failures.append("beat end: %s has an HP change but no number" % c.display_name)


func _on_round(n: int) -> void:
	_released[0] = true
	if _hud.shown_round() != n:
		_failures.append("round %d released but the HUD shows round %d" % [n, _hud.shown_round()])
	_round_releases.append(n)
	# The bill shows now: some squad MP is lower than at the last release.
	var now: Array = _hud_values()
	for i: int in _battle.squad.size():
		if int(now[i + 1][1]) < int(_last_release[i + 1][1]):
			_billed_on_release[0] = true
	_last_release = now


func _on_marker(_x: Variant = null) -> void:
	_released[0] = true
	_last_release = _hud_values()


## Plays one replay frame by frame, checking the HUD against the frame before.
func _play_replay() -> void:
	var frames: int = 0
	while _controller.get_state() != BattleReplayController.State.IDLE and frames < 5000:
		var before_values: Array = _hud_values()
		var plan: BeatPlan = _controller.get_current_plan()
		_released[0] = false
		_controller.advance(DT)
		frames += 1
		var now_values: Array = _hud_values()
		if not _released[0] and now_values != before_values:
			_failures.append("HUD changed with nothing released: %s -> %s" % [before_values, now_values])
		# A beat still in progress shows no number of its own yet.
		var current: BeatPlan = _controller.get_current_plan()
		if current != null and current == plan:
			for c: Combatant in current.hp_changes.keys():
				if _controller.get_post_impact_time() > 0.0 and _hud.number_over(c) != "":
					_failures.append("%s shows '%s' before its beat ended" % [c.display_name, _hud.number_over(c)])


func _choose(actor: Combatant, karen: Combatant, chef: Combatant) -> Array:
	var plan: Array = []
	if actor == karen:
		plan = [BattleContentSeam.move("move_speak_to_the_manager"), _battle.get_living_enemies()[0]] \
				if _battle.round_number == 2 else [Move.make_defend(), null]
	elif actor == chef and _battle.round_number >= 2:
		plan = [BattleContentSeam.move("move_family_meal"), null]
	if plan.is_empty() or not actor.can_afford((plan[0] as Move).mp_cost) \
			or not _battle.faction_rule.move_allowed(actor, plan[0]):
		plan = [Move.make_attack(), _battle.get_living_enemies()[0]]
	return plan


func test_hud_numbers_values_and_round_follow_the_replay() -> void:
	var karen: Combatant = _member(CharacterizationExpected.SQUAD_KAREN)
	var chef: Combatant = _member(CharacterizationExpected.SQUAD_CHEF)
	chef.hp = maxi(1, chef.hp - 6)  # so Family Meal heals someone
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_security_drone")]
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	_battle = BattleCore.new([karen, chef], enemies, rng, BattleContentSeam.rule("rule_megacorp_billing"))
	_controller = BattleReplayController.new(_battle, _windup, _ko, PresentationConfig.new())
	_hud = (load("res://src/battle/ui/battle_hud.tscn") as PackedScene).instantiate() as BattleHud
	add_child(_hud)
	auto_free(_hud)
	_controller.enqueue_reveal_gate()
	_battle.start_battle(false)
	_controller.resync()
	_hud.setup(_battle, _controller)
	_controller.beat_finished.connect(_on_beat_finished)
	_controller.round_advanced_after_replay.connect(_on_round)
	_controller.turn_started_after_replay.connect(_on_marker)
	_controller.battle_ended_after_replay.connect(_on_marker)
	_last_release = _hud_values()
	_controller.open_reveal_gate()
	var guard: int = 0
	while _battle.state == BattleCore.State.SQUAD_TURN and guard < 30:
		guard += 1
		var actor: Combatant = _battle.get_active_combatant()
		var choice: Array = _choose(actor, karen, chef)
		_battle.submit_action(choice[0], choice[1])
		_play_replay()
	assert_array(_failures).is_empty()
	assert_int(_numbers_checked[0]).is_greater(3)
	assert_array(_round_releases).is_not_empty()
	assert_bool(_billed_on_release[0]).override_failure_message(
			"no MegaCorp MP bill seen on a round release").is_true()
