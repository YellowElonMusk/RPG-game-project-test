## Story 011, AC-7a (GDD rule 3): `confirm` targets the eligible target
## nearest the probe point (`facing * body_radius` ahead of the leader). On
## an exact tie the order is NPC, CampSpot, `confirm`-started Static symbol,
## Interactable. An unresolved story encounter's boom is never returned. A
## target in reach of the leader's centre but not of the probe point is not
## targeted.
extends GdUnitTestSuite

const _AT: Vector2 = Vector2(12.0, 14.5)  # ProbeFixture.OPEN_SPOT
const _D: float = 1.0


func test_nearest_to_the_probe_point_wins() -> void:
	var point: Vector2 = _AT + Vector2.RIGHT * OverworldConfig.new().body_radius
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([
			ProbeFixture.npc(point + Vector2(0, -_D)),
			ProbeFixture.gag(point + Vector2(0, 0.5))]))
	ProbeFixture.stand(mode, _AT, Vector2.RIGHT)
	assert_object(mode.probe()).is_instanceof(GagInteractable)


func test_exact_ties_follow_npc_camp_static_interactable() -> void:
	# Four targets at exactly _D from the probe point, one per direction.
	# body_radius 0.5 keeps every coordinate exact in binary, so the ties
	# are exact rather than within rounding.
	var point: Vector2 = _AT + Vector2.RIGHT * 0.5
	var spots: Array[Vector2] = [point + Vector2(0, -_D), point + Vector2(_D, 0),
			point + Vector2(0, _D), point + Vector2(-_D, 0)]
	var expected: Array = ["NpcSpawn", "CampSpot", "EncounterSource", "GagInteractable"]
	for drop: int in 4:
		var extras: Array = []
		if drop <= 0:
			extras.append(ProbeFixture.npc(spots[0]))
		if drop <= 1:
			extras.append(ProbeFixture.camp(spots[1]))
		if drop <= 2:
			extras.append(ProbeFixture.static_symbol(spots[2]))
		extras.append(ProbeFixture.gag(spots[3]))
		var mode: OverworldMode = auto_free(ProbeFixture.make_mode(extras))
		mode.config.body_radius = 0.5
		ProbeFixture.stand(mode, _AT, Vector2.RIGHT)
		var got: Object = mode.probe()
		var name: String = got.get_class() if got.get_script() == null else got.get_script().get_global_name()
		assert_str(name).override_failure_message("with the first %d removed" % drop).is_equal(expected[drop])


func test_in_reach_of_the_centre_but_not_the_probe_point_is_ignored() -> void:
	var cfg := OverworldConfig.new()
	# Behind the leader: 1.0 m from its centre, 1.0 + body_radius from the
	# probe point, beyond interact_reach_m.
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([ProbeFixture.npc(_AT + Vector2.LEFT * 1.0)]))
	ProbeFixture.stand(mode, _AT, Vector2.RIGHT)
	assert_float(1.0 + cfg.body_radius).is_greater(cfg.interact_reach_m)
	assert_object(mode.probe()).is_null()
	ProbeFixture.stand(mode, _AT, Vector2.LEFT)
	assert_object(mode.probe()).is_instanceof(NpcSpawn)


func test_unresolved_story_encounter_boom_is_never_returned() -> void:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"encounter", load("res://data/encounters/enc_paris_permit_counter.tres"))
	mode.encounter_catalog = catalog
	mode.load_map((load("res://data/maps/paris_dungeon_placeholder.tscn") as PackedScene).instantiate() as OverworldMap)
	# Sweep the cells around the boom, every facing.
	for y in range(10, 16):
		for x in range(5, 11):
			for facing: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ProbeFixture.stand(mode, Vector2(x + 0.5, y + 0.5), facing)
				assert_bool(mode.probe() is CheckpointMarker).override_failure_message(
						"boom targeted from (%d, %d) facing %s" % [x, y, facing]).is_false()
