## Story 019, AC-8b (GDD rule 4; ADR-0012 §3): every `faction_` record a
## shipped map uses names a `patrol_archetype_id` that resolves
## (`MapValidator.check_patrol_archetypes()`, run by
## `tools/ci/validate_maps.gd` through `validate_catalog()`).
extends GdUnitTestSuite

const _MAP_DIR: String = "res://data/maps"
const _FACTION_DIR: String = "res://data/factions"


func test_every_faction_used_by_a_shipped_map_resolves() -> void:
	var maps: Array = _load_all(_MAP_DIR, "map_")
	var used: int = 0
	for rec: MapData in maps:
		if not rec.faction_id.is_empty():
			used += 1
	assert_int(used).is_greater(0)
	var errors: PackedStringArray = MapValidator.check_patrol_archetypes(
			maps, _shipped_catalog(), OverworldConfig.new())
	assert_array(Array(errors)).is_empty()


func test_dangling_patrol_archetype_id_fails_naming_faction_and_id() -> void:
	var catalog: RecordCatalogDouble = _shipped_catalog()
	var faction := FactionData.new()
	faction.id = "faction_fixture_dangling"
	faction.patrol_archetype_id = "patrol_fixture_missing"
	catalog.add(&"faction", faction)
	var errors: PackedStringArray = MapValidator.check_patrol_archetypes(
			[_map_using(faction.id)], catalog, OverworldConfig.new())
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("faction_fixture_dangling").contains("patrol_fixture_missing")


func test_empty_patrol_archetype_id_fails() -> void:
	var catalog: RecordCatalogDouble = _shipped_catalog()
	var faction := FactionData.new()
	faction.id = "faction_fixture_empty"
	catalog.add(&"faction", faction)
	var errors: PackedStringArray = MapValidator.check_patrol_archetypes(
			[_map_using(faction.id)], catalog, OverworldConfig.new())
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("faction_fixture_empty")


func test_unknown_faction_fails_naming_the_map() -> void:
	var errors: PackedStringArray = MapValidator.check_patrol_archetypes(
			[_map_using("faction_fixture_absent")], _shipped_catalog(), OverworldConfig.new())
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("map_fixture_patrol").contains("faction_fixture_absent")


func test_resolution_follows_the_configured_registry() -> void:
	var cfg := OverworldConfig.new()
	cfg.patrol_archetype_ids = ["patrol_fixture_other"]
	var errors: PackedStringArray = MapValidator.check_patrol_archetypes(
			_load_all(_MAP_DIR, "map_"), _shipped_catalog(), cfg)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("faction_bureaucratia")


func _map_using(faction_id: String) -> MapData:
	var rec := MapData.new()
	rec.id = "map_fixture_patrol"
	rec.faction_id = faction_id
	return rec


func _shipped_catalog() -> RecordCatalogDouble:
	var catalog := RecordCatalogDouble.new()
	for rec: Resource in _load_all(_FACTION_DIR, "faction_"):
		catalog.add(&"faction", rec)
	return catalog


func _load_all(dir: String, prefix: String) -> Array:
	var out: Array = []
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with(prefix) and file.ends_with(".tres"):
			out.append(load(dir.path_join(file)))
	return out
