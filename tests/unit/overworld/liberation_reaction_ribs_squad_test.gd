## Story 063, AC-26e (GDD rule 9): each last-act map's liberation reaction
## set has at least one entry tagged `ribs_squad`; a map without one is
## named. (AC-51 separately checks the tagged line really ribs the squad.)
extends GdUnitTestSuite


func test_the_shipped_last_act_maps_each_rib_the_squad() -> void:
	assert_array(Array(MapValidator.check_reaction_sets(_steps(), _maps()))).is_empty()


func test_a_map_with_no_ribbing_reaction_is_named() -> void:
	var maps: Dictionary = _maps()
	for npc: NpcSpawn in (maps["map_paris_town_placeholder"] as OverworldMap).npc_spawns():
		npc.ribs_squad = false
	var errors: PackedStringArray = MapValidator.check_reaction_sets(_steps(), maps)
	assert_array(Array(errors)).is_equal(["map_paris_town_placeholder: no liberation reaction is tagged ribs_squad"])


func test_a_ribbing_tag_outside_the_liberated_set_does_not_count() -> void:
	var maps: Dictionary = _maps()
	for npc: NpcSpawn in (maps["map_paris_segment_placeholder"] as OverworldMap).npc_spawns():
		if npc.ribs_squad:
			npc.liberated_role = ""
	var errors: PackedStringArray = MapValidator.check_reaction_sets(_steps(), maps)
	assert_array(Array(errors)).is_equal(["map_paris_segment_placeholder: no liberation reaction is tagged ribs_squad"])


func _steps() -> ChapterSteps:
	return load("res://data/chapters/chapter_paris_steps.tres")


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for name: String in ["town", "segment"]:
		out["map_paris_%s_placeholder" % name] = auto_free(
				(load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
	return out
