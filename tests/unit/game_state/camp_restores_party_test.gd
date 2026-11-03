## Stats & Damage rule 3: characters carry HP and MP between battles and are
## restored to full at camp. Nothing restored them: a squad member knocked
## out in a won battle stayed at 0 HP for the rest of the chapter, and Camp
## changed nothing.
extends GdUnitTestSuite

const CAMP_SCENE: String = "res://src/game_state/modes/interim_camp_mode.tscn"


func _hurt_party() -> Array[Combatant]:
	var a := Combatant.new("Karen", 34, 12, 8, 4, 6, false)
	var b := Combatant.new("Chef", 30, 14, 8, 4, 6, false)
	a.hp = 5
	a.mp = 1
	b.hp = 0  # knocked out in the last fight
	b.mp = 0
	return [a, b]


func test_arriving_at_camp_restores_full_hp_and_mp_including_knocked_out() -> void:
	var party: Array[Combatant] = _hurt_party()
	var camp: InterimCampMode = auto_free((load(CAMP_SCENE) as PackedScene).instantiate())
	camp.party_source = func() -> Array[Combatant]: return party

	camp.setup(null, CampEntryPayload.new())

	for member: Combatant in party:
		assert_int(member.hp).override_failure_message("%s not healed" % member.display_name).is_equal(member.max_hp)
		assert_int(member.mp).override_failure_message("%s MP not restored" % member.display_name).is_equal(member.max_mp)
		assert_bool(member.is_knocked_out()).is_false()


func test_camp_with_no_party_source_rests_nobody_and_does_not_fail() -> void:
	var camp: InterimCampMode = auto_free((load(CAMP_SCENE) as PackedScene).instantiate())
	camp.setup(null, CampEntryPayload.new())
	assert_str(camp.camp_id).is_equal("")
