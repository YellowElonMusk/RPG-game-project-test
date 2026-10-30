## Story 134 (ADR-0005 §14; test plan OW-T02): overworld cue nodes carry
## `capture_id` metadata the presentation capture tool resolves to its §14
## classes, each tag has a stable mask colour, and the O-07 "set hidden" ID
## pass helpers (hide set, visible fraction) work. Headless: the windowed
## render itself is the evidence capture (`capture_main.gd --fixture=cues`).
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _ACTOR: int = DioramaStage.LAYER_ACTORS


func _mode(map_name: String, extras: Array = []) -> OverworldMode:
	var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % map_name) as PackedScene) \
			.instantiate() as OverworldMap
	for n: Node3D in extras:
		map.add_child(n)
	var catalog := RecordCatalogDouble.new()
	for m: String in _MAPS:
		catalog.add(&"map", load("res://data/maps/map_paris_%s_placeholder.tres" % m))
	for s: int in [1, 2, 3]:
		catalog.add(&"occupation_stage", load("res://data/occupation_stages/ostage_bureaucratia_stage%d.tres" % s))
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(GameStateFixtures.make_machine_in_overworld()["machine"], null)
	mode.world_state = WorldState.new()
	mode.world_state.set_flag("permits_mandatory")
	mode.encounter_catalog = catalog
	auto_free(mode)
	mode.load_map(map)
	return mode


func _checkpoint() -> CheckpointMarker:
	var cp := CheckpointMarker.new()
	cp.name = "CidCheckpoint"
	cp.marker_id = &"cid_cp"
	cp.blocked_rect = Rect2(Vector2(1.0, 1.0), Vector2(1.0, 1.0))
	return cp


func test_tag_set_matches_the_capture_tool_classes() -> void:
	assert_array(CaptureIdTags.ALL).is_equal(PresentationCapture.CAPTURE_TAGS)
	assert_int(CaptureIdTags.ALL.size()).is_equal(11)
	assert_str(String(CaptureIdTags.META)).is_equal(String(PresentationCapture.META_CAPTURE_ID))


func test_every_tag_has_a_distinct_stable_palette_colour() -> void:
	var first: Dictionary = PresentationCapture.palette()
	var seen: Dictionary = {}
	for t: String in CaptureIdTags.ALL:
		assert_bool(first.has(t)).is_true()
		var c: Color = first[t]
		assert_bool(seen.has(c.to_html())).is_false()
		seen[c.to_html()] = true
		assert_that(PresentationCapture.palette()[t]).is_equal(c)


func test_each_tag_mask_selects_only_its_pixels() -> void:
	var pal: Dictionary = PresentationCapture.palette()
	var img := Image.create(CaptureIdTags.ALL.size(), 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for i: int in CaptureIdTags.ALL.size():
		img.set_pixel(i, 0, pal[CaptureIdTags.ALL[i]])
	for i: int in CaptureIdTags.ALL.size():
		var m: Dictionary = PresentationCapture.tag_mask(img, CaptureIdTags.ALL[i])
		assert_int(int(m["pixels"])).is_equal(1)
		assert_float((m["image"] as Image).get_pixel(i, 0).r).is_equal(1.0)
		assert_float((m["image"] as Image).get_pixel(i, 1).r).is_equal(0.0)


func test_relative_luminance_follows_wcag() -> void:
	assert_float(PresentationCapture.relative_luminance_of(Color.WHITE)).is_equal_approx(1.0, 1e-4)
	assert_float(PresentationCapture.relative_luminance_of(Color.BLACK)).is_equal_approx(0.0, 1e-6)
	var v: float = 128.0 / 255.0
	var lin: float = pow((v + 0.055) / 1.055, 2.4)
	assert_float(PresentationCapture.relative_luminance_of(Color(v, v, v))).is_equal_approx(lin, 1e-4)
	var g: Color = Color(0.0, 1.0, 0.0)
	assert_float(PresentationCapture.relative_luminance_of(g)).is_equal_approx(0.7152, 1e-4)


func test_symbol_sprite_tag_follows_its_cue_state() -> void:
	assert_str(CaptureIdTags.symbol_tag(SymbolBrain.SubState.PATROL)).is_equal(CaptureIdTags.SYMBOL)
	assert_str(CaptureIdTags.symbol_tag(SymbolBrain.SubState.NOTICING)).is_equal(CaptureIdTags.NOTICE_SLIP)
	assert_str(CaptureIdTags.symbol_tag(SymbolBrain.SubState.CHASING)).is_equal(CaptureIdTags.CHASE_TAG)
	assert_str(CaptureIdTags.symbol_tag(SymbolBrain.SubState.STUNNED)).is_equal(CaptureIdTags.STUN_POSE)
	assert_str(CaptureIdTags.symbol_tag(SymbolBrain.SubState.RETURNING)).is_equal(CaptureIdTags.SYMBOL)


func test_loaded_map_tags_beacons_and_exit_patches_as_beacon() -> void:
	var mode: OverworldMode = _mode("segment")
	var map: OverworldMap = mode.get_map()
	var beacons: int = 0
	for n: Node in map.find_children("*", "Marker3D", true, false):
		if n is WaypointBeacon:
			beacons += 1
			assert_str(CaptureIdTags.tag_of(n)).is_equal(CaptureIdTags.BEACON)
	assert_int(beacons).is_greater(0)
	for exit: MapExit in map.map_exits():
		var patch: GeometryInstance3D = map.get_node("PlaceholderSet/ExitPatch_%s" % exit.marker_id)
		assert_str(PresentationCapture.class_of(patch, _ACTOR, map)).is_equal(CaptureIdTags.BEACON)
	# Untagged walls stay `set`.
	var floor_node: GeometryInstance3D = map.get_node(^"PlaceholderSet/Floor")
	assert_str(PresentationCapture.class_of(floor_node, _ACTOR, map)).is_equal("set")


func test_checkpoint_tags_closed_then_open_after_opening() -> void:
	var mode: OverworldMode = _mode("segment", [_checkpoint()])
	var map: OverworldMap = mode.get_map()
	var cp: Node = map.get_node(^"CidCheckpoint")
	var bar: GeometryInstance3D = map.get_node(^"PlaceholderSet/Checkpoint_cid_cp")
	assert_str(CaptureIdTags.tag_of(cp)).is_equal(CaptureIdTags.CHECKPOINT_CLOSED)
	assert_str(PresentationCapture.class_of(bar, _ACTOR, map)).is_equal(CaptureIdTags.CHECKPOINT_CLOSED)
	mode.open_checkpoint(&"cid_cp")
	assert_str(CaptureIdTags.tag_of(cp)).is_equal(CaptureIdTags.CHECKPOINT_OPEN)


func test_unknown_tag_is_refused() -> void:
	var n: Node3D = auto_free(Node3D.new())
	CaptureIdTags.tag(n, "exit_beacon_typo")
	assert_bool(n.has_meta(CaptureIdTags.META)).is_false()


func test_set_hidden_pass_hides_only_untagged_set_geometry_and_restores() -> void:
	var root: Node3D = auto_free(Node3D.new())
	var wall := MeshInstance3D.new()
	wall.layers = DioramaStage.LAYER_SET
	root.add_child(wall)
	var cue := MeshInstance3D.new()
	cue.layers = DioramaStage.LAYER_SET
	CaptureIdTags.tag(cue, CaptureIdTags.BEACON)
	wall.add_child(cue)  # a cue under set geometry keeps rendering
	var actor := MeshInstance3D.new()
	actor.layers = _ACTOR
	root.add_child(actor)
	var restore: Dictionary = PresentationCapture.hide_set_geometry(root, _ACTOR)
	assert_int(restore.size()).is_equal(1)
	assert_int(wall.layers).is_equal(0)
	assert_int(cue.layers).is_equal(DioramaStage.LAYER_SET)
	assert_int(actor.layers).is_equal(_ACTOR)
	PresentationCapture.restore_layers(restore)
	assert_int(wall.layers).is_equal(DioramaStage.LAYER_SET)


func test_visible_fraction_is_normal_over_unoccluded() -> void:
	var normal: Dictionary = {"beacon": {"pixels": 30}, "symbol": {"pixels": 0}}
	var hidden: Dictionary = {"beacon": {"pixels": 120}, "symbol": {"pixels": 40}, "set": {"pixels": 5}}
	var f: Dictionary = PresentationCapture.visible_fractions(normal, hidden)
	assert_float(float(f["beacon"])).is_equal_approx(30.0 / 120.0, 1e-6)
	assert_float(float(f["symbol"])).is_equal(0.0)
	assert_bool(f.has("set")).is_false()
	assert_bool(f.has("camp_sign")).is_false()
