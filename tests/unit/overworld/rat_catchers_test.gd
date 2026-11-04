## The Rat Catchers (narrative bible §6.5): human bounty hunters whose
## ambushes rise with alien points (never at 0), at most twice per street
## segment, and whose Captain comes once per chapter on the walk home.
extends GdUnitTestSuite

const _LONDON: String = "map_london_segment_placeholder"
const _SYDNEY: String = "map_sydney_segment_placeholder"
const _TRIALS: int = 400


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _cfg() -> RatCatcherConfig:
	var cfg := RatCatcherConfig.new()
	cfg.tier_by_map = {_LONDON: "london", _SYDNEY: "sydney"}
	cfg.ambush_base_chance = 0.2
	cfg.ambush_per_point = 0.15
	cfg.ambush_max_chance = 0.8
	cfg.ambushes_per_map_max = 2
	cfg.captain_min_alien_points = 1
	return cfg


func _ws(alien: int) -> WorldState:
	var ws := WorldState.new()
	ws.alien_points = alien
	return ws


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Ambushes out of `_TRIALS` first entries at `alien` points (fixed seed).
func _ambush_count(alien: int) -> int:
	var rng := _rng(42)
	var hits: int = 0
	for i: int in _TRIALS:
		if not RatCatchers.pick(_ws(alien), _LONDON, false, rng, _cfg()).is_empty():
			hits += 1
	return hits


func test_no_alien_points_means_no_rat_catchers() -> void:
	assert_float(RatCatchers.ambush_chance(0, _cfg())).is_equal(0.0)
	assert_int(_ambush_count(0)).is_equal(0)
	# Nor a Captain on the walk home.
	assert_str(RatCatchers.pick(_ws(0), _LONDON, true, _rng(1), _cfg())).is_empty()


func test_ambush_chance_rises_with_alien_points_and_caps() -> void:
	assert_float(RatCatchers.ambush_chance(1, _cfg())).is_equal_approx(0.35, 0.0001)
	assert_float(RatCatchers.ambush_chance(2, _cfg())).is_equal_approx(0.5, 0.0001)
	assert_float(RatCatchers.ambush_chance(9, _cfg())).is_equal_approx(0.8, 0.0001)
	var one: int = _ambush_count(1)
	var three: int = _ambush_count(3)
	assert_int(one).override_failure_message("1 alien point never ambushed").is_greater(0)
	assert_int(three).override_failure_message("3 points (%d) not above 1 point (%d)" % [three, one]) \
			.is_greater(one)


func test_an_ambush_names_the_chapters_encounter() -> void:
	var cfg := _cfg()
	cfg.ambush_base_chance = 1.0
	assert_str(RatCatchers.pick(_ws(1), _LONDON, false, _rng(3), cfg)).is_equal("enc_rat_ambush_london")
	assert_str(RatCatchers.pick(_ws(1), _SYDNEY, false, _rng(3), cfg)).is_equal("enc_rat_ambush_sydney")
	# A map that is not a street segment is never ambushed.
	assert_str(RatCatchers.pick(_ws(4), "map_london_town_placeholder", false, _rng(3), cfg)).is_empty()


func test_ambushes_stop_at_the_per_map_cap() -> void:
	var cfg := _cfg()
	cfg.ambush_base_chance = 1.0
	cfg.ambush_max_chance = 1.0
	var ws := _ws(2)
	for i: int in 2:
		var enc: String = RatCatchers.pick(ws, _LONDON, false, _rng(i), cfg)
		assert_str(enc).is_equal("enc_rat_ambush_london")
		RatCatchers.mark_met(ws, _LONDON, enc, cfg)
	assert_int(RatCatchers.ambushes_met(ws, _LONDON, cfg)).is_equal(2)
	assert_str(RatCatchers.pick(ws, _LONDON, false, _rng(9), cfg)).is_empty()
	# Another city's segment keeps its own count.
	assert_str(RatCatchers.pick(ws, _SYDNEY, false, _rng(9), cfg)).is_equal("enc_rat_ambush_sydney")


func test_the_captain_comes_once_per_chapter_on_the_walk_home() -> void:
	var cfg := _cfg()
	var ws := _ws(1)
	var enc: String = RatCatchers.pick(ws, _LONDON, true, _rng(5), cfg)
	assert_str(enc).is_equal("enc_rat_captain_london")
	RatCatchers.mark_met(ws, _LONDON, enc, cfg)
	assert_bool(ws.has_flag("rat_captain_met_london")).is_true()
	assert_str(RatCatchers.pick(ws, _LONDON, true, _rng(6), cfg)) \
			.override_failure_message("the Captain came twice in one chapter").is_empty()
	# The next chapter has its own Captain.
	assert_str(RatCatchers.pick(ws, _SYDNEY, true, _rng(6), cfg)).is_equal("enc_rat_captain_sydney")


func test_the_captain_needs_enough_alien_points() -> void:
	var cfg := _cfg()
	cfg.captain_min_alien_points = 2
	assert_str(RatCatchers.pick(_ws(1), _LONDON, true, _rng(5), cfg)).is_empty()
	assert_str(RatCatchers.pick(_ws(2), _LONDON, true, _rng(5), cfg)).is_equal("enc_rat_captain_london")


func test_meetings_survive_a_save_round_trip() -> void:
	var cfg := _cfg()
	var ws := _ws(2)
	ws.map_id = _LONDON
	RatCatchers.mark_met(ws, _LONDON, "enc_rat_ambush_london", cfg)
	RatCatchers.mark_met(ws, _LONDON, "enc_rat_captain_london", cfg)
	# Through the real participant and a JSON round trip, as a save file does.
	var data: Dictionary = JSON.parse_string(JSON.stringify(ws.to_dict()))
	var back := WorldState.new()
	var participant := OverworldSaveParticipant.new(back, null, Callable())
	participant.commit(participant.stage(data, SaveReader.new(data, BattleCatalog.shipped())))
	assert_int(RatCatchers.ambushes_met(back, _LONDON, cfg)).is_equal(1)
	assert_bool(back.has_flag(RatCatchers.captain_flag("london"))).is_true()


func test_every_shipped_encounter_exists() -> void:
	var cfg := RatCatcherConfig.load_default()
	for map_id: String in cfg.tier_by_map:
		var tier: String = cfg.tier_by_map[map_id]
		assert_bool(ResourceLoader.exists("res://data/maps/%s.tres" % map_id)) \
				.override_failure_message("no map %s" % map_id).is_true()
		assert_bool(ResourceLoader.exists("res://data/encounters/%s.tres" % RatCatchers.captain_encounter(tier))) \
				.override_failure_message("no Captain for %s" % tier).is_true()
		if tier != "paris":  # Paris is met at 0 alien points: Captain only
			assert_bool(ResourceLoader.exists("res://data/encounters/%s.tres" % RatCatchers.ambush_encounter(tier))) \
					.override_failure_message("no ambush for %s" % tier).is_true()
	assert_object(Conversation.load_by_id(cfg.ambush_conversation_id)).is_not_null()
	assert_object(Conversation.load_by_id(cfg.captain_conversation_id)).is_not_null()
