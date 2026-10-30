## Story 066, AC-27b (GDD rules 13, 17): with `region_liberation_flag` set,
## each Paris map's load (the map-entry commit, before the reveal) treats
## every clutter marker as liberated, keeps the stage, takes the map's
## liberated lighting profile and set kit, takes stage 1's civilian density
## and ambience bed, leaves every symbol inactive, and activates the
## liberated set: the mairie-queue civilians, a grumbler and the
## "Bureaucratia had a point" item.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
## The stage each map holds after New Game (permits_mandatory set).
const _STAGES: Dictionary = {"town": 1, "segment": 2, "dungeon": 3, "boss_chamber": 0}


func test_every_paris_map_loads_liberated_with_its_stage_kept() -> void:
	var stage1: OccupationStageData = load("res://data/occupation_stages/ostage_bureaucratia_stage1.tres")
	for name: String in _MAPS:
		var mode: OverworldMode = _mode(name, true)
		var rec: MapData = _record(name)
		assert_int(mode.current_stage).override_failure_message("%s stage changed" % name).is_equal(_STAGES[name])
		assert_int(mode.get_encounter_sources().size()).override_failure_message("%s has active symbols" % name).is_equal(0)
		for gag: GagInteractable in mode.get_map().gags():
			if gag.is_liberatable() or gag.is_decree() or not gag.clutter_kind.is_empty():
				assert_bool(mode.is_gag_active(gag)).override_failure_message(
						"%s: clutter %s still active" % [name, gag.marker_id]).is_false()
		assert_float(mode.civilian_density).override_failure_message("%s density" % name).is_equal(stage1.civilian_density)
		assert_str(mode.ambience_bed_id).override_failure_message("%s ambience" % name).is_equal(stage1.ambience_bed_id)
		if not rec.liberated_profile_id.is_empty():
			assert_str(String(mode.presentation_profile_id)).is_equal(rec.liberated_profile_id)
			assert_str(mode.set_kit_id).is_equal(rec.liberated_kit_id)


func test_a_higher_stage_clutter_marker_is_liberated_too() -> void:
	var extra: GagInteractable = ProbeFixture.gag(Vector2(12.0, 14.5), GagInteractable.Response.LINE, &"gag_stage3_poster")
	extra.clutter_kind = "poster"
	extra.min_stage = 3
	extra.liberation_flag = "paris_liberated"
	var mode: OverworldMode = _mode("segment", true, [extra])
	assert_bool(mode.is_gag_active(extra)).is_false()


func test_the_town_liberated_set_is_active_only_once_liberated() -> void:
	var roles: Dictionary = {}
	var mode: OverworldMode = _mode("town", true)
	for npc: NpcSpawn in mode.get_map().npc_spawns():
		if not npc.liberated_role.is_empty():
			assert_bool(mode.is_npc_active(npc)).is_true()
			roles[npc.liberated_role] = int(roles.get(npc.liberated_role, 0)) + 1
	for gag: GagInteractable in mode.get_map().gags():
		if not gag.liberated_role.is_empty():
			assert_bool(mode.is_gag_active(gag)).is_true()
			roles[gag.liberated_role] = int(roles.get(gag.liberated_role, 0)) + 1
	assert_int(int(roles.get("mairie_queue", 0))).is_greater_equal(1)
	assert_int(int(roles.get("grumbler", 0))).is_greater_equal(1)
	assert_int(int(roles.get("had_a_point", 0))).is_greater_equal(1)
	var occupied: OverworldMode = _mode("town", false)
	for npc: NpcSpawn in occupied.get_map().npc_spawns():
		if not npc.liberated_role.is_empty():
			assert_bool(occupied.is_npc_active(npc)).is_false()
			assert_bool((occupied.get_map().get_node("PlaceholderSet/Npc_%s" % npc.marker_id) as Node3D).visible).is_false()
	for gag: GagInteractable in occupied.get_map().gags():
		if not gag.liberated_role.is_empty():
			assert_bool(occupied.is_gag_active(gag)).is_false()


func test_occupied_maps_take_their_stage_record_presentation() -> void:
	var mode: OverworldMode = _mode("segment", false)
	var stage2: OccupationStageData = load("res://data/occupation_stages/ostage_bureaucratia_stage2.tres")
	assert_str(String(mode.presentation_profile_id)).is_equal(stage2.lighting_profile_id)
	assert_str(mode.set_kit_id).is_equal(stage2.set_kit_id)
	assert_float(mode.civilian_density).is_equal(stage2.civilian_density)


func test_the_liberated_kit_strips_faction_dressing() -> void:
	var dressing := Node3D.new()
	dressing.add_to_group(OverworldMap.FACTION_DRESSING_GROUP)
	var mode: OverworldMode = _mode("segment", true, [dressing])
	assert_bool(dressing.visible).is_false()
	var occupied_dressing := Node3D.new()
	occupied_dressing.add_to_group(OverworldMap.FACTION_DRESSING_GROUP)
	_mode("segment", false, [occupied_dressing])
	assert_bool(occupied_dressing.visible).is_true()


func _record(name: String) -> MapData:
	return load("res://data/maps/map_paris_%s_placeholder.tres" % name)


## A mode on Paris map `name`, after New Game's flags, with `paris_liberated`
## set when `liberated`, loaded outside a transition (so the commit runs at
## once, as `mode_entered` would before the reveal).
func _mode(name: String, liberated: bool, extras: Array = []) -> OverworldMode:
	var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene) \
			.instantiate() as OverworldMap
	for n: Node3D in extras:
		map.add_child(n)
	var catalog := RecordCatalogDouble.new()
	for m: String in _MAPS:
		catalog.add(&"map", _record(m))
	for s: int in [1, 2, 3]:
		catalog.add(&"occupation_stage", load("res://data/occupation_stages/ostage_bureaucratia_stage%d.tres" % s))
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(GameStateFixtures.make_machine_in_overworld()["machine"], null)
	mode.world_state = WorldState.new()
	mode.world_state.set_flag("permits_mandatory")
	if liberated:
		mode.world_state.set_flag("paris_liberated")
	mode.encounter_catalog = catalog
	auto_free(mode)
	mode.load_map(map)
	return mode
