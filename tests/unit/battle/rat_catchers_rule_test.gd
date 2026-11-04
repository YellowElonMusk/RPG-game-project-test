## The Rat Catchers' fight (narrative bible §6.5): human, so no alien rule
## (nothing banned, a neutral banner); each role alternates its two moves;
## and a beaten Captain never gets the spare-or-finish prompt, which follows
## alien bosses only (§6.2).
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _descriptor(enc_id: String) -> EncounterDescriptor:
	var rec: EncounterData = BattleCatalog.shipped().get_record(&"encounter", enc_id) as EncounterData
	return OverworldMode.build_descriptor(rec)


func _build(enc_id: String) -> BattleCore:
	var payload := BattleEntryPayload.new()
	payload.descriptor = _descriptor(enc_id)
	payload.party.assign(ChapterFlow.build_squad(BattleCatalog.shipped()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result: BattleFactory.BattleBuildResult = BattleFactory.build(payload, rng)
	assert_array(result.errors).is_empty()
	return result.core


func test_the_factory_builds_every_rat_catcher_fight() -> void:
	for enc_id: String in ["enc_rat_ambush_london", "enc_rat_ambush_sydney", "enc_rat_ambush_newyork",
			"enc_rat_captain_paris", "enc_rat_captain_london", "enc_rat_captain_sydney", "enc_rat_captain_newyork"]:
		var core: BattleCore = _build(enc_id)
		assert_object(core).override_failure_message("no battle for %s" % enc_id).is_not_null()
		assert_object(core.faction_rule).is_instanceof(RatCatchersRule)


func test_no_alien_rule_restricts_anything() -> void:
	var core: BattleCore = _build("enc_rat_ambush_london")
	var rule: FactionRule = core.faction_rule
	assert_bool(rule.specials_allowed(1)).is_true()
	assert_str(rule.get_banner_text(1)).contains("No alien rule")
	for member: Combatant in core.squad:
		var moves: Array[Move] = [Move.make_attack()]
		moves.append_array(SquadMoves.moves_for(member))
		for m: Move in moves:
			assert_bool(rule.move_allowed(member, m)).is_true()
			# Nothing repeats-blocks either (Liberty-7's rule is not in force).
			rule.on_action_resolved(member, m)
			assert_bool(rule.move_allowed(member, m)).is_true()


func test_each_role_alternates_its_moves() -> void:
	var core: BattleCore = _build("enc_rat_captain_london")
	var rule: FactionRule = core.faction_rule
	var squad: Array[Combatant] = core.get_living_squad()
	var names: Dictionary = {}
	for enemy: Combatant in core.enemies:
		var odd: Array = rule.choose_enemy_action(enemy, squad, 1, core.rng)
		var even: Array = rule.choose_enemy_action(enemy, squad, 2, core.rng)
		names[enemy.record_id] = [(odd[0]["move"] as Move).display_name, (even[0]["move"] as Move).display_name]
		if enemy.is_boss:
			assert_int(odd.size()).override_failure_message("Wanted Poster hits everyone").is_equal(squad.size())
	assert_array(names["enemy_rat_captain_london"]).is_equal(["Wanted Poster", "Citizen's Arrest"])
	assert_array(names["enemy_rat_trapper_london"]).is_equal(["Net Throw", "Rat Trap"])
	assert_array(names["enemy_rat_scout_london"]).is_equal(["Headlamp Glare", "Tunnel Rush"])


func test_a_beaten_captain_gets_no_spare_or_finish_prompt() -> void:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()), true,
			null, null, _descriptor("enc_rat_captain_london"))
	auto_free(h.mode)
	h.mode.world_state = WorldState.new()
	h.reveal()
	h.mode.settle_replay()
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.VICTORY)
	h.mode.settle_replay()
	h.mode.step_replay(h.mode.presentation_config.input_guard + 0.05)
	h.mode.handle_action(InputActions.CONFIRM, true)
	assert_bool(h.mode.boss_choice().visible) \
			.override_failure_message("a human boss got the spare-or-finish prompt").is_false()
	assert_int(h.mode.world_state.street_cred + h.mode.world_state.alien_points).is_equal(0)
