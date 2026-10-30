extends SceneTree
## Builds the placeholder Paris dungeon and boss-chamber map scenes
## (`data/maps/paris_dungeon_placeholder.tscn`,
## `data/maps/paris_boss_chamber_placeholder.tscn`) from the ASCII layouts
## below, so their walk layers are reviewable as text and rebuildable (story
## 075; GDD rule 11 map table, rules 13 and 13a). `#` is wall, `.` is floor;
## one character is one `cell_m` (1 m) cell, and ground (x, y) is world
## (x, z). The tile set is the segment map's (`walk` custom data on atlas
## tile (0, 0)).
##
## Usage, from the project root:
##
##   godot --headless --path . -s res://tools/maps/build_paris_dungeon_maps.gd
##
## Re-run after editing a layout or a marker below; the scenes are
## overwritten. Exit 0 on success, 1 if a scene fails to save.

const _TILESET_SOURCE: String = "res://data/maps/paris_segment_placeholder.tscn"
const _OUT_DIR: String = "res://data/maps"

## Dungeon: the first room (south, rows 23-33) holds the segment entry and
## exit, the pre-dungeon camp inside the entry's safe zone, and the Permit
## Counter in front of the closed boom (rows 21-22, the only way north). The
## hall (rows 1-20) is split by a wall on row 11 with two gaps: the near one
## (east, x 18-20) on the short route, watched by a Clerk, and the far one
## (west, x 1-3), the longer safe detour (rule 12 pressure floor and bypass
## lane, stories 083 and 085). The boss chamber exit is at the top.
const _DUNGEON: Array[String] = [
	"########################",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#...##############...###",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"################..######",
	"################..######",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"########################",
]

## Boss chamber: the Supervisor stands at the far end, the dungeon entry and
## exit at the near end.
const _BOSS: Array[String] = [
	"##############",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"#............#",
	"##############",
]


func _initialize() -> void:
	var source_map: OverworldMap = (load(_TILESET_SOURCE) as PackedScene).instantiate() as OverworldMap
	var tile_set: TileSet = source_map.walk_layer.tile_set.duplicate(true) as TileSet
	source_map.free()
	var ok: bool = true
	ok = _save(_build_dungeon(tile_set), "paris_dungeon_placeholder") and ok
	ok = _save(_build_boss_chamber(tile_set), "paris_boss_chamber_placeholder") and ok
	quit(0 if ok else 1)


func _build_dungeon(tile_set: TileSet) -> OverworldMap:
	var map: OverworldMap = _map("ParisDungeonPlaceholder", "map_paris_dungeon_placeholder",
			_DUNGEON, tile_set, Vector2i(17, 31), Color(0.5, 0.48, 0.46))
	_exit(map, "ExitToSegment", &"exit_to_segment", "map_paris_segment_placeholder",
			&"from_dungeon", Rect2(16, 33, 2, 1))
	_entry(map, "EntryFromSegment", &"from_segment", Vector2(17.0, 31.0), Vector2.UP)
	_exit(map, "ExitToBossChamber", &"exit_to_boss_chamber", "map_paris_boss_chamber_placeholder",
			&"from_dungeon", Rect2(16, 1, 2, 1))
	_entry(map, "EntryFromBossChamber", &"from_boss_chamber", Vector2(17.0, 3.5), Vector2.DOWN)
	var camp := CampSpot.new()
	camp.name = "CampPreDungeon"
	camp.marker_id = &"camp_pre_dungeon"
	camp.camp_id = "camp_paris_pre_dungeon"
	camp.return_entry_id = &"from_segment"
	_place(map, camp, Vector2(13.5, 29.5))
	var boom := CheckpointMarker.new()
	boom.name = "PermitBoom"
	boom.marker_id = &"cp_permit_boom"
	boom.requirement_flag = "counter_cleared"
	boom.obtained_at = "enc_paris_permit_counter"
	boom.failure_outcome = CheckpointMarker.FailureOutcome.ENCOUNTER
	boom.linked_encounter_id = "enc_paris_permit_counter"
	boom.blocked_rect = Rect2(16, 21, 2, 2)
	boom.return_marker = Vector2(16.5, 26.0)
	boom.return_facing = Vector2.DOWN
	_place(map, boom, Vector2(17.0, 22.0))
	var counter := EncounterSymbol.new()
	counter.name = "SymbolPermitCounter"
	counter.encounter_id = "enc_paris_permit_counter"
	counter.symbol_id = "sym_paris_permit_counter"
	counter.patrol_path = PackedVector2Array([Vector2(16.5, 23.5)])
	counter.is_static = true
	counter.start_on = EncounterSymbol.StartOn.CONFIRM
	counter.return_marker = Vector2(16.5, 26.0)
	counter.checkpoint_id = &"cp_permit_boom"
	counter.bark_line = "Take a number."
	counter.fled_line = "Your number was called. You were absent. Please take a new number."
	_place(map, counter, Vector2(16.5, 23.5))
	# Rule 13a: the camp decree announcing the counter, on first sight.
	var decree := GagInteractable.new()
	decree.name = "DecreeTakeANumber"
	decree.marker_id = &"decree_take_a_number"
	decree.text = "ALL PERMITS MUST BE PROCESSED. TAKE A NUMBER."
	decree.decree_first_sight = "sym_paris_permit_counter"
	_place(map, decree, Vector2(12.5, 28.5))
	# Denser symbols than the segment (GDD rule 11): a Clerk pacing the first
	# room's east wall, and one in the hall's near gap, across the short
	# route; both clear of every safe zone (story 077), the west gap left as
	# the bypass lane (story 083) and the near gap as the pressure (085).
	_patrol(map, "SymbolClerksFirstRoom", "enc_paris_clerks_east", "sym_dungeon_clerks_first_room",
			PackedVector2Array([Vector2(20.5, 23.5), Vector2(20.5, 26.5)]))
	_patrol(map, "SymbolClerksHall", "enc_paris_clerks_west", "sym_dungeon_clerks_hall",
			PackedVector2Array([Vector2(18.5, 11.5), Vector2(20.5, 11.5)]))
	# Story 103 (GDD `symbol_density`, dungeon band 80/120 cells per symbol):
	# W 670 needs 6-8 patrols. Four more, found by search against every
	# validator (bypass lane via the west gap, pressure floor, safe zones) and
	# then by story 087's walk-ins: the camera looks north, so a 2.5 m wall
	# hides ~4.3 m of floor north of it; patrols keep out of those shadows,
	# and a Clerk walked up on from the north sits at the frame's near
	# edge, so the south-half ones stand under the long hall wall, where no
	# approach comes from the north.
	_patrol(map, "SymbolClerksHallSouthFarWest", "enc_paris_clerks_east", "sym_dungeon_clerks_hall_south_far_west",
			PackedVector2Array([Vector2(7.5, 16.5), Vector2(9.5, 16.5)]))
	_patrol(map, "SymbolClerksHallSouthWest", "enc_paris_clerks_west", "sym_dungeon_clerks_hall_south_west",
			PackedVector2Array([Vector2(11.5, 17.5), Vector2(11.5, 19.5)]))
	_patrol(map, "SymbolClerksHallNorthWest", "enc_paris_clerks_east", "sym_dungeon_clerks_hall_north_west",
			PackedVector2Array([Vector2(5.5, 1.5), Vector2(7.5, 1.5)]))
	_patrol(map, "SymbolClerksHallNorth", "enc_paris_clerks_west", "sym_dungeon_clerks_hall_north",
			PackedVector2Array([Vector2(13.5, 8.5), Vector2(15.5, 8.5)]))
	return map


func _patrol(map: OverworldMap, node_name: String, enc_id: String, symbol_id: String,
		path: PackedVector2Array) -> void:
	var sym := EncounterSymbol.new()
	sym.name = node_name
	sym.encounter_id = enc_id
	sym.symbol_id = symbol_id
	sym.patrol_path = path
	_place(map, sym, path[0])


func _build_boss_chamber(tile_set: TileSet) -> OverworldMap:
	var map: OverworldMap = _map("ParisBossChamberPlaceholder", "map_paris_boss_chamber_placeholder",
			_BOSS, tile_set, Vector2i(7, 10), Color(0.46, 0.44, 0.5))
	_exit(map, "ExitToDungeon", &"exit_to_dungeon", "map_paris_dungeon_placeholder",
			&"from_boss_chamber", Rect2(6, 12, 2, 1))
	_entry(map, "EntryFromDungeon", &"from_dungeon", Vector2(7.0, 10.5), Vector2.UP)
	var boss := EncounterSymbol.new()
	boss.name = "SymbolSupervisor"
	boss.encounter_id = "enc_paris_supervisor"
	boss.symbol_id = "sym_paris_supervisor"
	boss.patrol_path = PackedVector2Array([Vector2(6.5, 3.5)])
	boss.is_static = true
	boss.start_on = EncounterSymbol.StartOn.CONTACT_OR_CONFIRM
	_place(map, boss, Vector2(6.5, 3.5))
	return map


func _map(node_name: String, map_id: String, rows: Array[String], tile_set: TileSet,
		spawn: Vector2i, floor_color: Color) -> OverworldMap:
	var map := OverworldMap.new()
	map.name = node_name
	map.map_id = map_id
	map.leader_spawn_cell = spawn
	map.floor_color = floor_color
	var layer := TileMapLayer.new()
	layer.name = "WalkLayer"
	# Story 079: TileMapLayer collision defaults on; shipped maps have none.
	layer.collision_enabled = false
	layer.visible = false
	layer.tile_set = tile_set
	for y in rows.size():
		for x in rows[y].length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0) if rows[y][x] == "." else Vector2i(1, 0))
	map.add_child(layer)
	layer.owner = map
	map.walk_layer = layer
	return map


func _exit(map: OverworldMap, node_name: String, marker_id: StringName, target_map: String,
		target_entry: StringName, rect: Rect2) -> void:
	var exit := MapExit.new()
	exit.name = node_name
	exit.marker_id = marker_id
	exit.target_map_id = target_map
	exit.target_entry_id = target_entry
	exit.trigger_rect = rect
	_place(map, exit, rect.get_center())


func _entry(map: OverworldMap, node_name: String, marker_id: StringName, at: Vector2,
		facing: Vector2) -> void:
	var entry := EntryPoint.new()
	entry.name = node_name
	entry.marker_id = marker_id
	entry.facing = facing
	_place(map, entry, at)


func _place(map: OverworldMap, marker: Node3D, at: Vector2) -> void:
	marker.position = Vector3(at.x, 0.0, at.y)
	map.add_child(marker)
	marker.owner = map


func _save(map: OverworldMap, file_name: String) -> bool:
	var scene := PackedScene.new()
	var err: Error = scene.pack(map)
	if err == OK:
		err = ResourceSaver.save(scene, _OUT_DIR.path_join(file_name + ".tscn"))
	map.free()
	if err != OK:
		printerr("build_paris_dungeon_maps: %s failed (%s)" % [file_name, error_string(err)])
		return false
	print("build_paris_dungeon_maps: wrote ", file_name)
	return true
