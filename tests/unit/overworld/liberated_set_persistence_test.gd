## Story 059, AC-25 (GDD rule 9, Edge Cases): a Victory over a linked Clerk
## puts its marker in the map's liberated set in `on_thawed`. When the Clerk
## respawns, and after a stage raise, the marker stays hidden; beating the
## respawned Clerk adds nothing; the set survives save and load.
extends GdUnitTestSuite

const _CLERK: String = "enc_paris_clerks_east"
const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_victory_liberates_and_it_stays_through_respawn_stage_and_rebeat() -> void:
	var mode: OverworldMode = _mode()
	var poster: GagInteractable = _poster(mode)
	assert_bool(mode.is_gag_active(poster)).is_true()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.world_state.is_liberated(_SEGMENT_ID, &"poster_permit_queue")).is_true()
	assert_bool(mode.is_gag_active(poster)).is_false()
	# The Clerk respawns on the next visit, and the stage rises.
	mode.world_state.on_map_entered("map_paris_town_placeholder", WorldState.EntryKind.MAP_ENTRY)
	mode.world_state.set_flag("permits_mandatory")
	mode.world_state.store_stage(_SEGMENT_ID, 3)
	mode = _reload(mode)
	poster = _poster(mode)
	var clerk_back: bool = false
	for s: EncounterSource in mode.get_encounter_sources():
		clerk_back = clerk_back or s.symbol_id == _CLERK
	assert_bool(clerk_back).is_true()
	assert_bool(mode.is_gag_active(poster)).is_false()
	# Beating the respawned Clerk adds nothing.
	mode.set("_payoff_lines", [] as Array[String])
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_array(mode.get("_payoff_lines")).is_empty()
	assert_bool(mode.is_removing(poster)).is_false()


func test_the_liberated_set_survives_save_and_load() -> void:
	var mode: OverworldMode = _mode()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	var saved: Dictionary = mode.world_state.to_dict()
	var restored := WorldState.new()
	restored.from_dict(_through_json(saved))
	assert_bool(restored.is_liberated(_SEGMENT_ID, &"poster_permit_queue")).is_true()


func test_region_liberation_frees_every_marker_and_inactivates_every_symbol() -> void:
	var mode: OverworldMode = _mode()
	mode.world_state.set_flag("paris_liberated")
	mode.world_state.on_map_entered("map_paris_town_placeholder", WorldState.EntryKind.MAP_ENTRY)
	mode = _reload(mode)
	assert_int(mode.get_encounter_sources().size()).is_equal(0)
	for gag: GagInteractable in mode.get_map().gags():
		if gag.is_liberatable() or gag.is_decree():
			assert_bool(mode.is_gag_active(gag)).is_false()


## The participant's stage reads JSON numbers back as floats; emulate it.
func _through_json(d: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	parsed["party_pos"] = Vector2(parsed["party_pos"][0], parsed["party_pos"][1])
	parsed["party_facing"] = Vector2(parsed["party_facing"][0], parsed["party_facing"][1])
	return parsed


func _poster(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.marker_id == &"poster_permit_queue":
			return gag
	return null


## A fresh mode on the segment sharing `old`'s world state and catalog, as
## the game builds one per map load.
func _reload(old: OverworldMode) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = old.config
	mode.setup(old.get("_machine"), null)
	mode.world_state = old.world_state
	mode.encounter_catalog = old.encounter_catalog
	auto_free(mode)
	mode.load_map((load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap)
	return mode


func _mode() -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var rec: EncounterData = mode.encounter_catalog.get_record(&"encounter", _CLERK)
	rec.respawn = true
	# The double is a boss by default; a boss Victory would liberate the region.
	rec.is_boss = false
	(mode.encounter_catalog as RecordCatalogDouble).add(&"map", load("res://data/maps/map_paris_segment_placeholder.tres"))
	mode.world_state.on_map_entered(_SEGMENT_ID, WorldState.EntryKind.MAP_ENTRY)
	# Far from the poster, so its removal is immediate (off screen).
	mode.set_leader_position(Vector2(3.0, 14.5))
	return mode
