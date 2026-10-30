## Story 103, AC-41 (GDD Formulas `symbol_density`): at every reachable
## stage (symbols carry no stage gate, so one count), each banded map's
## patrolling symbols lie within `[N_min, N_max]`, with `N_min` at least 1;
## Town and the boss chamber have no band (story 075 checks Town 0, boss
## only). Coverage is reported, not gated.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _DUNGEON_ID: String = "map_paris_dungeon_placeholder"


func test_the_band_formula_matches_the_gdd_example() -> void:
	# GDD: an overworld segment with W = 720 holds 3-5 symbols.
	var cfg := OverworldConfig.new()
	assert_object(MapValidator.density_band("overworld", 720, cfg)).is_equal(Vector2i(3, 5))
	assert_object(MapValidator.density_band("dungeon", 670, cfg)).is_equal(Vector2i(6, 8))
	# N_min never falls below 1.
	assert_int(MapValidator.density_band("overworld", 40, cfg).x).is_equal(1)


func test_the_shipped_maps_are_in_band_and_coverage_is_reported() -> void:
	var result: Array = MapValidator.check_density(_maps(), _records(), OverworldConfig.new())
	assert_array(Array(result[0])).is_empty()
	assert_int((result[1] as PackedStringArray).size()).is_equal(2)
	assert_str("\n".join(result[1])).contains("coverage")


func test_the_old_two_clerk_dungeon_is_under_its_band() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON_ID]
	for sym: EncounterSymbol in dungeon.symbol_markers():
		if String(sym.symbol_id).begins_with("sym_dungeon_clerks_hall_"):
			dungeon.remove_child(sym)
			sym.free()
	var errors: PackedStringArray = MapValidator.check_density(maps, _records(), OverworldConfig.new())[0]
	assert_array(Array(errors)).is_equal(
			["%s: 2 patrolling symbol(s), outside the dungeon band [6, 8] for W 670" % _DUNGEON_ID])


func _records() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % name)
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		out["map_paris_%s_placeholder" % name] = auto_free(
				(load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
	return out
