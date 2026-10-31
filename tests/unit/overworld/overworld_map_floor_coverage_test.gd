## Sprite-camera story 039 (AC-35 [C] Coverage, Overworld half): the
## placeholder set's floor covers the follow camera's whole ground footprint
## on every shipped map, wherever the camera's map clamp can put its focus,
## at every supported aspect. The 039 capture found the town spawn showing
## the clear colour past the south edge: the floor was sized to the walk
## grid only, and a map smaller than the footprint centres the camera
## (`FollowCamera.clamp_or_centre`), so it sees past both edges.
extends GdUnitTestSuite

const _MAPS: Array[String] = [
	"res://data/maps/paris_town_placeholder.tscn",
	"res://data/maps/paris_segment_placeholder.tscn",
	"res://data/maps/paris_dungeon_placeholder.tscn",
	"res://data/maps/paris_boss_chamber_placeholder.tscn",
]
## 4:3, 16:9, 2560x1080 (64:27) and 3440x1440 (43:18): the GDD's supported
## range, including the real "21:9" panels the 039 capture runs at.
const _ASPECTS: Array[float] = [4.0 / 3.0, 16.0 / 9.0, 64.0 / 27.0, 43.0 / 18.0]


func test_floor_covers_camera_footprint_on_every_shipped_map() -> void:
	var cfg := PresentationConfig.new()
	for path: String in _MAPS:
		_assert_covered(path, cfg)


func test_floor_covers_camera_footprint_for_a_wider_camera_config() -> void:
	# A camera config change must move the floor with it (data, not a
	# constant): a taller, wider-FOV camera sees much more ground.
	var cfg := PresentationConfig.new()
	cfg.follow_camera_height = 20.0
	cfg.follow_camera_fov_degrees = 24.0
	for path: String in _MAPS:
		_assert_covered(path, cfg)


func _assert_covered(path: String, cfg: PresentationConfig) -> void:
	var map: OverworldMap = auto_free((load(path) as PackedScene).instantiate() as OverworldMap)
	var grid: WalkGrid = map.bake_walk_grid(OverworldConfig.new())
	map.build_set(grid, cfg)
	var floor_node: MeshInstance3D = map.get_node(^"PlaceholderSet/Floor") as MeshInstance3D
	var plane: Vector2 = (floor_node.mesh as PlaneMesh).size
	var floor_rect := Rect2(Vector2(floor_node.position.x, floor_node.position.z) - plane * 0.5, plane)
	var bounds: Rect2 = OverworldMap.ground_bounds(grid)
	var focuses: Array[Vector2] = [map.spawn_position(grid), bounds.position, bounds.end,
			Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y),
			bounds.get_center()]
	for entry: EntryPoint in map.entry_points():
		focuses.append(entry.ground_position(map))
	for aspect: float in _ASPECTS:
		var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(cfg.follow_camera_height,
				cfg.follow_camera_pitch_degrees, cfg.follow_camera_fov_degrees, aspect)
		for target: Vector2 in focuses:
			var f: Vector2 = FollowCamera.clamp_to_map(target, fp, bounds.position, bounds.end)
			# Yaw 0: the far edge (widest, `w_far`) lies toward map -y, the
			# near edge toward +y (south).
			var seen := Rect2(f.x - fp.w_far, f.y - fp.a_far, 2.0 * fp.w_far, fp.a_far + fp.a_near)
			assert_bool(floor_rect.grow(1e-3).encloses(seen)) \
					.override_failure_message("%s aspect %.3f focus %s: floor %s does not cover footprint %s" \
					% [path.get_file(), aspect, f, floor_rect, seen]).is_true()
