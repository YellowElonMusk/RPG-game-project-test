## Story 087 (GDD rule 12 "Visibility"), the level-review half: a patrol's
## approaches are walk-grid entries into its `see_m` disc, measured along
## the walk grid, reachable from an EntryPoint, one per 45-degree sector,
## each placing the leader `see_m + 0.1 m` from the patrol point nearest it.
## The occlusion half needs a window and runs in
## `tools/level_review/walkin_capture.gd` (evidence and report in
## production/qa/evidence/story-087-patrol-visibility/).
extends GdUnitTestSuite


func test_see_m_matches_the_gdd_example() -> void:
	# 3.0 + 0.3 + (3.5 + 0.6 * 3.5) * 0.25 = 4.70
	assert_float(OverworldConfig.new().see_m()).is_equal_approx(4.70, 1e-6)


func test_every_patrol_has_approaches_one_per_sector() -> void:
	var cfg := OverworldConfig.new()
	for name: String in ["segment", "dungeon"]:
		var map: OverworldMap = _map(name)
		for sym: EncounterSymbol in map.symbol_markers():
			if sym.is_static:
				assert_int(PatrolApproaches.of(map, sym, cfg).size()).is_equal(0)
				continue
			var approaches: Array = PatrolApproaches.of(map, sym, cfg)
			assert_int(approaches.size()).override_failure_message("%s has no approach" % sym.symbol_id).is_greater(0)
			var sectors: Dictionary = {}
			for a: PatrolApproaches.Approach in approaches:
				assert_bool(sectors.has(a.sector)).is_false()
				sectors[a.sector] = true
				assert_float(a.leader_at.distance_to(a.symbol_at)).is_equal_approx(cfg.see_m() + 0.1, 1e-4)
				assert_vector(PatrolApproaches.nearest_patrol_point(sym, a.symbol_at)).is_equal_approx(a.symbol_at, Vector2.ONE * 1e-4)
		map.free()


func test_the_disc_is_measured_along_the_walk_grid() -> void:
	# The first-room Clerk is within see_m of the hall in a straight line,
	# but the boom wall is between: no approach comes from the hall.
	var map: OverworldMap = _map("dungeon")
	var clerk: EncounterSymbol = null
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.symbol_id == "sym_dungeon_clerks_first_room":
			clerk = sym
	for a: PatrolApproaches.Approach in PatrolApproaches.of(map, clerk, OverworldConfig.new()):
		assert_int(a.entry_cell.y).override_failure_message("approach from the hall at %s" % a.entry_cell).is_greater(22)
	map.free()


func test_nearest_patrol_point_includes_a_loop_closing_segment() -> void:
	var sym := EncounterSymbol.new()
	sym.patrol_path = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	sym.path_mode = SymbolBrain.PathMode.PINGPONG
	var open: Vector2 = PatrolApproaches.nearest_patrol_point(sym, Vector2(4, 6))
	sym.path_mode = SymbolBrain.PathMode.LOOP
	var loop: Vector2 = PatrolApproaches.nearest_patrol_point(sym, Vector2(4, 6))
	sym.free()
	assert_vector(open).is_equal(Vector2(4, 0))
	assert_vector(loop).is_equal_approx(Vector2(5, 5), Vector2.ONE * 1e-5)


func _map(name: String) -> OverworldMap:
	return (load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate() as OverworldMap
