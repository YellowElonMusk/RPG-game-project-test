## An Encounter may now repeat an enemy (ruling 2026-11-03). Three "Clerk"
## cards and three "Clerk" target buttons left the player guessing which one
## they were hitting, so repeated names are lettered in roster order.
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _foe(name: String) -> Combatant:
	return Combatant.new(name, 40, 0, 11, 6, 8, true)


func test_repeated_names_get_letters_in_roster_order() -> void:
	var foes: Array[Combatant] = [_foe("Supervisor"), _foe("Clerk"), _foe("Clerk"), _foe("Clerk")]
	BattleFactory.letter_duplicate_names(foes)
	var names: Array[String] = []
	for f: Combatant in foes:
		names.append(f.display_name)
	assert_array(names).is_equal(["Supervisor", "Clerk A", "Clerk B", "Clerk C"])


func test_a_lone_enemy_keeps_its_name() -> void:
	var foes: Array[Combatant] = [_foe("Clerk")]
	BattleFactory.letter_duplicate_names(foes)
	assert_str(foes[0].display_name).is_equal("Clerk")


## MegaCorp picks Upsell for a Middle Manager; a lettered one ("Middle
## Manager B") must still get it, not fall through to the drone's attack.
func test_lettered_middle_manager_still_upsells() -> void:
	var rule := MegaCorpRule.new()
	var mm: Combatant = MegaCorpRule.make_middle_manager()
	var foes: Array[Combatant] = [mm, MegaCorpRule.make_middle_manager()]
	BattleFactory.letter_duplicate_names(foes)
	assert_str(mm.display_name).is_equal("Middle Manager A")
	var hero := Combatant.new("Hero", 30, 10, 8, 4, 6, false)
	var squad: Array[Combatant] = [hero]
	var actions: Array = rule.choose_enemy_action(mm, squad, 2, RandomNumberGenerator.new())
	assert_str((actions[0]["move"] as Move).display_name).is_equal(rule._named_attack("move_upsell").display_name)
