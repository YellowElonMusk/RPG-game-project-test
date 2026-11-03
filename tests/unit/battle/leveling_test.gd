## Leveling (design/gdd/leveling.md AC-1..AC-5).
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _squad() -> Array[Combatant]:
	return ChapterFlow.build_squad(BattleCatalog.shipped())


func _by_id(squad: Array[Combatant], id: String) -> Combatant:
	for m: Combatant in squad:
		if m.record_id == id:
			return m
	return null


func test_curve_matches_the_gdd() -> void:
	assert_array([Leveling.xp_total(1), Leveling.xp_total(2), Leveling.xp_total(3),
			Leveling.xp_total(4), Leveling.xp_total(5)]).is_equal([0, 20, 60, 120, 200])


## AC-1: 40 XP takes a standing level-1 member to level 2 with exactly its
## growth; a knocked-out member gains nothing.
func test_standing_members_level_up_by_their_growth_and_knocked_out_ones_do_not() -> void:
	var squad := _squad()
	var karen: Combatant = _by_id(squad, "char_karen")
	var chef: Combatant = _by_id(squad, "char_michelin_chef")
	chef.hp = 0
	var hp0: int = karen.max_hp
	var def0: int = karen.defense
	var lines: Array[String] = Leveling.award(squad, 40, BattleCatalog.shipped())
	assert_int(karen.level).is_equal(2)
	assert_int(karen.xp).is_equal(40)
	assert_int(karen.max_hp).is_equal(hp0 + 4)
	assert_int(karen.hp).is_equal(hp0 + 4)
	assert_int(karen.defense).is_equal(def0 + 2)
	assert_int(chef.level).is_equal(1)
	assert_int(chef.xp).is_equal(0)
	assert_bool(lines.has("Karen reached level 2!")).is_true()


## AC-2: 120 XP gives level 4 and three lines for that member.
func test_one_award_can_cross_several_levels() -> void:
	var squad := _squad()
	var karen: Combatant = _by_id(squad, "char_karen")
	var lines: Array[String] = Leveling.award(squad, 120, BattleCatalog.shipped())
	assert_int(karen.level).is_equal(4)
	var karens: int = lines.filter(func(l: String) -> bool: return l.begins_with("Karen ")).size()
	assert_int(karens).is_equal(3)


## AC-3: a save and load keeps level, XP, HP and MP and rebuilds the stats.
func test_squad_save_round_trip_rebuilds_stats_from_the_record() -> void:
	var store := SquadStore.new()
	store.rebuild(BattleCatalog.shipped())
	Leveling.award(store.squad, 120, BattleCatalog.shipped())
	var karen: Combatant = _by_id(store.squad, "char_karen")
	karen.hp = 7
	var expect := {"level": karen.level, "xp": karen.xp, "max_hp": karen.max_hp, "attack": karen.attack}
	var p := SquadSaveParticipant.new(store, BattleCatalog.shipped())
	var data: Dictionary = JSON.parse_string(JSON.stringify(p.capture()))

	var back := SquadStore.new()
	var p2 := SquadSaveParticipant.new(back, BattleCatalog.shipped())
	p2.commit(p2.stage(data, SaveReader.new(data, BattleCatalog.shipped())))
	back.rebuild(BattleCatalog.shipped())
	var k2: Combatant = _by_id(back.squad, "char_karen")
	assert_int(k2.level).is_equal(expect["level"])
	assert_int(k2.xp).is_equal(expect["xp"])
	assert_int(k2.max_hp).is_equal(expect["max_hp"])
	assert_int(k2.attack).is_equal(expect["attack"])
	assert_int(k2.hp).is_equal(7)


## GDD edge case: an unknown character is dropped and reported; numbers clamp.
func test_unknown_character_is_dropped_and_numbers_clamp() -> void:
	var data := {"members": {"char_nobody": {"level": 3}, "char_karen": {"level": 500, "xp": -4, "hp": 9999, "mp": 0}}}
	var reader := SaveReader.new(data, BattleCatalog.shipped())
	var store := SquadStore.new()
	var p := SquadSaveParticipant.new(store, BattleCatalog.shipped())
	p.commit(p.stage(data, reader))
	assert_bool(reader.dropped.size() == 1 and reader.dropped[0].contains("char_nobody")).is_true()
	store.rebuild(BattleCatalog.shipped())
	var karen: Combatant = _by_id(store.squad, "char_karen")
	assert_int(karen.level).is_equal(Leveling.LEVEL_MAX)
	assert_int(karen.xp).is_equal(0)
	assert_int(karen.hp).is_equal(karen.max_hp)


## AC-4: New Game starts everyone at level 1, 0 XP, full HP/MP, empty wallet.
func test_new_game_resets_the_squad_and_the_wallet() -> void:
	var store := SquadStore.new()
	store.pending = {"char_karen": {"level": 5, "xp": 200, "hp": 1, "mp": 0}}
	SquadSaveParticipant.new(store, BattleCatalog.shipped()).reset_to_new_game()
	store.rebuild(BattleCatalog.shipped())
	for m: Combatant in store.squad:
		assert_int(m.level).is_equal(1)
		assert_int(m.hp).is_equal(m.max_hp)
	var ws := WorldState.new()
	ws.money = 50
	ws.reset_to_new_game()
	assert_int(ws.money).is_equal(0)


## AC-5 + rule 5: a won fight shows level lines and banks the money.
func test_victory_levels_up_shows_lines_and_banks_money() -> void:
	var squad := _squad()
	for m: Combatant in squad:
		m.xp = 15  # 5 short of level 2; the harness Clerk pays 8
	var h := BattleModeHarness.create(self, squad)
	auto_free(h.mode)
	h.mode.world_state = WorldState.new()
	h.reveal()
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.VICTORY)
	h.mode.settle_replay()
	assert_str(h.mode.results_panel().levels_text()).contains("reached level 2!")
	assert_int(h.mode.world_state.money).is_equal(5)
