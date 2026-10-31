## Story sprite-camera-presentation 069 (AC-64; ADR-0005 §11): Boot's
## warm-up stage covers every combination play can reach. The rendering half
## needs a window (`tools/capture/pipeline_compile_benchmark.gd`); this suite
## checks the plan it renders, built from the shipped catalog: every map,
## every faction's ordinary and boss fight on every battle stage, every
## shipped lighting profile, and that it never runs headless.
extends GdUnitTestSuite


func _catalog() -> ContentCatalogService:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	if catalog.state != ContentCatalogService.State.READY:
		ContentBootstrap.run(catalog)
	return catalog


func _of_kind(plan: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in plan:
		if String(e["kind"]) == kind:
			out.append(e)
	return out


func test_profile_ids_lists_every_shipped_profile() -> void:
	var ids: PackedStringArray = PipelineWarmup.profile_ids()
	for want: String in ["battle", "boss_bureaucratia", "boss_megacorp", "camp", "defeat",
			"overworld", "overworld_liberated", "title", "victory"]:
		assert_bool(ids.has(want)).override_failure_message("missing profile %s" % want).is_true()


func test_build_plan_has_one_overworld_entry_per_map_record() -> void:
	var catalog: ContentCatalogService = _catalog()
	var plan: Array[Dictionary] = PipelineWarmup.build_plan(catalog)
	var maps: Array[Dictionary] = _of_kind(plan, PipelineWarmup.KIND_OVERWORLD)
	assert_int(maps.size()).is_equal(catalog.all_records(&"map").size())
	var ids: PackedStringArray = PackedStringArray()
	for e: Dictionary in maps:
		ids.append(String(e["map_id"]))
	assert_bool(ids.has("map_paris_town_placeholder")).is_true()
	assert_bool(ids.has("map_paris_boss_chamber_placeholder")).is_true()


func test_build_plan_has_a_boss_fight_for_every_faction_with_a_boss() -> void:
	var plan: Array[Dictionary] = PipelineWarmup.build_plan(_catalog())
	var boss_factions: PackedStringArray = PackedStringArray()
	for e: Dictionary in _of_kind(plan, PipelineWarmup.KIND_BATTLE):
		var d: EncounterDescriptor = e["descriptor"]
		if d.is_boss:
			boss_factions.append(d.faction_id)
	assert_bool(boss_factions.has("faction_bureaucratia")).is_true()
	assert_bool(boss_factions.has("faction_megacorp")).is_true()


func test_build_plan_boss_fight_has_exactly_one_boss_enemy() -> void:
	var catalog: ContentCatalogService = _catalog()
	for e: Dictionary in _of_kind(PipelineWarmup.build_plan(catalog), PipelineWarmup.KIND_BATTLE):
		var d: EncounterDescriptor = e["descriptor"]
		var bosses: int = 0
		for id: String in d.enemy_ids:
			if (catalog.get_record(&"enemy", id) as EnemyData).is_boss:
				bosses += 1
		assert_int(bosses).is_equal(1 if d.is_boss else 0)


func test_build_plan_has_an_ordinary_fight_for_every_faction_with_enemies() -> void:
	var plan: Array[Dictionary] = PipelineWarmup.build_plan(_catalog())
	var factions: PackedStringArray = PackedStringArray()
	for e: Dictionary in _of_kind(plan, PipelineWarmup.KIND_BATTLE):
		var d: EncounterDescriptor = e["descriptor"]
		if not d.is_boss:
			factions.append(d.faction_id)
	assert_bool(factions.has("faction_bureaucratia")).is_true()
	assert_bool(factions.has("faction_megacorp")).is_true()


func test_build_plan_battles_use_every_shipped_battle_stage_id() -> void:
	var catalog: ContentCatalogService = _catalog()
	var stages: PackedStringArray = PackedStringArray()
	for e: Dictionary in _of_kind(PipelineWarmup.build_plan(catalog), PipelineWarmup.KIND_BATTLE):
		stages.append((e["descriptor"] as EncounterDescriptor).battle_stage_id)
	for rec: Resource in catalog.all_records(&"encounter"):
		assert_bool(stages.has((rec as EncounterData).battle_stage_id)).is_true()


func test_wanted_headless_is_false() -> void:
	assert_bool(PipelineWarmup.wanted("headless", ContentCatalogService.State.READY)).is_false()


func test_wanted_windowed_ready_catalog_is_true() -> void:
	assert_bool(PipelineWarmup.wanted("Windows", ContentCatalogService.State.READY)).is_true()


func test_wanted_failed_catalog_is_false() -> void:
	assert_bool(PipelineWarmup.wanted("Windows", ContentCatalogService.State.FAILED)).is_false()
