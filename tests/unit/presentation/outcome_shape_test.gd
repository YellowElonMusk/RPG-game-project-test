## Story 017 (GDD sprite-camera-presentation AC-14b; ADR-0006 §7): every
## shipped move, resolved by a real seeded `BattleCore`, becomes a beat plan
## with the table's actor pose, reactions, numbers and punch. No number ever
## reads "0".
extends GdUnitTestSuite

const SEED: int = 17
const FRAME_STEP: float = 1.0 / 60.0

var _config: PresentationConfig
var _battle: BattleCore
var _controller: BattleReplayController
var _plans: Array[BeatPlan] = []


func before_test() -> void:
	BattleContentSeam.ensure_catalog()
	_config = PresentationConfig.new()
	_plans.clear()


func after_test() -> void:
	if _controller != null:
		_controller.dispose()
	_controller = null
	_battle = null


func _member(display: String, is_enemy: bool) -> Combatant:
	return Combatant.new(display, 40, 99, 10, 5, 10, is_enemy)


## Builds a seeded battle whose enemies never act, wired to a controller
## that records every plan as it starts.
func _start(squad: Array[Combatant], enemies: Array[Combatant]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_battle = BattleCore.new(squad, enemies, rng, BattleContentSeam.scripted_rule([]))
	_controller = BattleReplayController.new(_battle,
			func(_p: BeatPlan) -> float: return 0.3,
			func(_c: Combatant) -> float: return 0.0, _config)
	_controller.beat_started.connect(func(p: BeatPlan) -> void: _plans.append(p))
	_battle.start_battle(false)


## Re-takes the displayed snapshot after a test arranged vitals directly.
func _settle() -> void:
	_controller.resync()


## Submits `move` for the active squad member and returns its beat plan.
func _resolve(move: Move, target: Combatant) -> BeatPlan:
	var count: int = _plans.size()
	assert_object(_battle.submit_action(move, target)).is_not_null()
	_controller.advance(FRAME_STEP)
	assert_int(_plans.size()).is_equal(count + 1)
	return _plans[count]


func _none(_key: StringName) -> bool:
	return false


func _all(_key: StringName) -> bool:
	return true


func _assert_no_zero(plan: BeatPlan) -> void:
	for text: String in plan.numbers().values():
		assert_str(text).is_not_equal("0")
		assert_str(text).is_not_equal("+0")
		assert_str(text).is_not_equal("-0")


func test_attack_damaging_attack_hit_one_number_punch() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	var e2 := _member("E2", true)
	_start([a] as Array[Combatant], [e, e2] as Array[Combatant])
	var plan := _resolve(Move.make_attack(), e)
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.HIT})
	assert_str(String(BeatPlan.reaction_animation(plan.reactions[e], _all))).is_equal("hit")
	assert_dict(plan.numbers()).is_equal({e: BeatPlan.number_text(e.hp - e.max_hp)})
	assert_bool(plan.punch).is_true()
	_assert_no_zero(plan)


func test_attack_that_fells_knockout_one_number_punch() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	var e2 := _member("E2", true)
	_start([a] as Array[Combatant], [e, e2] as Array[Combatant])
	BattleContentSeam.arrange_vitals(e, 1, 0)
	_settle()
	var plan := _resolve(Move.make_attack(), e)
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.KNOCKOUT})
	assert_str(String(BeatPlan.reaction_animation(plan.reactions[e], _all))).is_equal("knockout")
	assert_dict(plan.numbers()).is_equal({e: "-1"})
	assert_bool(plan.punch).is_true()
	assert_bool(plan.knockout).is_true()


func test_attack_zero_damage_fixture_hit_no_number_no_punch() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	_start([a] as Array[Combatant], [e] as Array[Combatant])
	# Fixture: a real Attack never deals 0, so the outcome is emitted directly.
	_battle.action_resolved.emit(BattleOutcome.new(a, "Attack", Move.Category.ATTACK, e,
			0, 0, false, _battle.round_number))
	_controller.advance(FRAME_STEP)
	var plan: BeatPlan = _plans.back()
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.HIT})
	assert_dict(plan.numbers()).is_empty()
	assert_bool(plan.punch).is_false()


func test_defend_defend_pose_no_reactions_no_numbers() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	_start([a] as Array[Combatant], [e] as Array[Combatant])
	var plan := _resolve(Move.make_defend(), null)
	assert_str(String(plan.action_animation(_all))).is_equal("defend")
	assert_dict(plan.reactions).is_empty()
	assert_dict(plan.numbers()).is_empty()
	assert_bool(plan.punch).is_false()


func test_family_meal_heals_others_numbers_for_healed_only() -> void:
	var chef := _member("Chef", false)
	var hurt := _member("Hurt", false)
	var full := _member("Full", false)
	var e := _member("E", true)
	_start([chef, hurt, full] as Array[Combatant], [e] as Array[Combatant])
	BattleContentSeam.arrange_vitals(chef, 10, chef.max_mp)
	BattleContentSeam.arrange_vitals(hurt, 12, hurt.max_mp)
	_settle()
	var move: Move = SquadSpecials.make_family_meal()
	var heal: int = SquadSpecials.calculate_heal(move.power, chef)
	var plan := _resolve(move, null)
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_str(String(plan.action_animation(_all))).is_equal("family_meal")
	assert_dict(plan.reactions).is_equal({hurt: BeatPlan.Reaction.HEAL})
	assert_str(String(BeatPlan.reaction_animation(BeatPlan.Reaction.HEAL, _all))).is_equal("heal")
	assert_str(String(BeatPlan.reaction_animation(BeatPlan.Reaction.HEAL, _none))).is_equal("")
	assert_dict(plan.numbers()).is_equal({
		chef: BeatPlan.number_text(mini(heal, chef.max_hp - 10)),
		hurt: BeatPlan.number_text(mini(heal, hurt.max_hp - 12)),
	})
	assert_bool(plan.numbers().has(full)).is_false()
	assert_bool(plan.punch).is_false()
	_assert_no_zero(plan)


func test_appetizers_single_heal_one_number_no_punch() -> void:
	var chef := _member("Chef", false)
	var hurt := _member("Hurt", false)
	var e := _member("E", true)
	_start([chef, hurt] as Array[Combatant], [e] as Array[Combatant])
	BattleContentSeam.arrange_vitals(hurt, 12, hurt.max_mp)
	_settle()
	var move: Move = SquadSpecials.make_appetizer()
	var heal: int = SquadSpecials.calculate_heal(move.power, chef)
	var plan := _resolve(move, hurt)
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_dict(plan.reactions).is_equal({hurt: BeatPlan.Reaction.HEAL})
	assert_dict(plan.numbers()).is_equal({hurt: BeatPlan.number_text(mini(heal, hurt.max_hp - 12))})
	assert_bool(plan.punch).is_false()


func test_home_run_direct_damage_hit_one_number_punch() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	var e2 := _member("E2", true)
	_start([a] as Array[Combatant], [e, e2] as Array[Combatant])
	var plan := _resolve(SquadSpecials.make_home_run(), e)
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_str(String(plan.action_animation(_all))).is_equal("home_run")
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.HIT})
	assert_dict(plan.numbers()).is_equal({e: BeatPlan.number_text(e.hp - e.max_hp)})
	assert_bool(plan.punch).is_true()


func test_home_run_that_fells_knockout() -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	var e2 := _member("E2", true)
	_start([a] as Array[Combatant], [e, e2] as Array[Combatant])
	BattleContentSeam.arrange_vitals(e, 1, 0)
	_settle()
	var plan := _resolve(SquadSpecials.make_home_run(), e)
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.KNOCKOUT})
	assert_bool(plan.punch).is_true()


func test_status_specials_status_or_hit_no_number_no_punch(move_id: String, test_parameters := [
		["move_speak_to_the_manager"], ["move_viral_stunt"]]) -> void:
	var a := _member("A", false)
	var e := _member("E", true)
	_start([a] as Array[Combatant], [e] as Array[Combatant])
	var move: Move = BattleContentSeam.move(move_id)
	var plan := _resolve(move, e)
	assert_str(String(plan.action_animation(_none))).is_equal("attack")
	assert_dict(plan.reactions).is_equal({e: BeatPlan.Reaction.STATUS})
	assert_str(String(BeatPlan.reaction_animation(BeatPlan.Reaction.STATUS, _all))).is_equal("status")
	assert_str(String(BeatPlan.reaction_animation(BeatPlan.Reaction.STATUS, _none))).is_equal("hit")
	assert_dict(plan.numbers()).is_empty()
	assert_bool(plan.punch).is_false()


func test_number_text_zero_is_empty() -> void:
	assert_str(BeatPlan.number_text(0)).is_equal("")
	assert_str(BeatPlan.number_text(5)).is_equal("+5")
	assert_str(BeatPlan.number_text(-5)).is_equal("-5")
