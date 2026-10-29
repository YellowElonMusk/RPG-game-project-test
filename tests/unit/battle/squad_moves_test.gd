## Story 007 QA Test Cases: `SquadMoves.moves_for()` returns Attack, Defend
## and exactly the record's specials for each of the four squad characters
## (the Chef has two), and Attack/Defend only for an enemy or an unknown
## combatant (no `move_ids` set).
extends GdUnitTestSuite


func test_moves_for_karen_returns_attack_defend_and_speak_to_the_manager() -> void:
	var karen: Combatant = _make_squad_member("Karen", PackedStringArray(["move_speak_to_the_manager"]))

	var moves: Array[Move] = SquadMoves.moves_for(karen)

	_assert_display_names(moves, ["Attack", "Defend", "Speak to the Manager"])


func test_moves_for_michelin_chef_returns_attack_defend_and_both_specials() -> void:
	var chef: Combatant = _make_squad_member(
			"Michelin Chef", PackedStringArray(["move_appetizer", "move_family_meal"]))

	var moves: Array[Move] = SquadMoves.moves_for(chef)

	_assert_display_names(moves, ["Attack", "Defend", "Appetizer", "Family Meal"])


func test_moves_for_florida_man_returns_attack_defend_and_viral_stunt() -> void:
	var florida_man: Combatant = _make_squad_member(
			"Florida Man", PackedStringArray(["move_viral_stunt"]))

	var moves: Array[Move] = SquadMoves.moves_for(florida_man)

	_assert_display_names(moves, ["Attack", "Defend", "Viral Stunt"])


func test_moves_for_baguette_thrower_returns_attack_defend_and_home_run() -> void:
	var baguette_thrower: Combatant = _make_squad_member(
			"Baguette Thrower", PackedStringArray(["move_home_run"]))

	var moves: Array[Move] = SquadMoves.moves_for(baguette_thrower)

	_assert_display_names(moves, ["Attack", "Defend", "Home Run"])


func test_moves_for_enemy_returns_attack_and_defend_only() -> void:
	var clerk: Combatant = BureaucratiaRule.make_clerk()

	var moves: Array[Move] = SquadMoves.moves_for(clerk)

	_assert_display_names(moves, ["Attack", "Defend"])


func test_moves_for_unknown_combatant_returns_attack_and_defend_only() -> void:
	# A squad member built without a backing character record (move_ids left
	# at its default, empty, array) -- e.g. a test squad.
	var unknown: Combatant = Combatant.new("Recruit", 30, 10, 12, 8, 10, false)

	var moves: Array[Move] = SquadMoves.moves_for(unknown)

	_assert_display_names(moves, ["Attack", "Defend"])


func _make_squad_member(display_name: String, move_ids: PackedStringArray) -> Combatant:
	var combatant := Combatant.new(display_name, 30, 12, 12, 8, 10, false)
	combatant.move_ids = move_ids
	return combatant


func _assert_display_names(moves: Array[Move], expected: Array) -> void:
	var names: Array[String] = []
	for move: Move in moves:
		names.append(move.display_name)
	assert_array(names).override_failure_message(
			"expected %s, got %s" % [expected, names]).is_equal(expected)
