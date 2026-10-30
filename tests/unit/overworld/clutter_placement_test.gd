## Story 064, AC-26c (GDD rule 9 "Placement"): every clutter marker naming
## a symbol lies within `R_vis` of a vertex of that symbol's patrol (the
## shipped camera), so winning shows its result.
extends GdUnitTestSuite

const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_r_vis_is_the_smallest_edge_over_every_aspect() -> void:
	# GDD example: at h 11.5 m the binding edge is 4:3's side, 4.99 m.
	var cam := PresentationConfig.new()
	cam.follow_camera_height = 11.5
	assert_float(ChaseVisibility.r_vis(cam, OverworldConfig.new().walk_speed)).is_equal_approx(4.99, 0.01)


func test_the_shipped_clutter_is_in_view_of_its_patrol() -> void:
	var map: OverworldMap = _segment()
	assert_array(Array(MapValidator.check_clutter_placement({_SEGMENT_ID: map},
			OverworldConfig.new(), PresentationConfig.new()))).is_empty()


func test_clutter_beyond_r_vis_of_every_vertex_is_named() -> void:
	var map: OverworldMap = _segment()
	var radius: float = ChaseVisibility.r_vis(PresentationConfig.new(), OverworldConfig.new().walk_speed)
	var queue: GagInteractable = null
	for gag: GagInteractable in map.gags():
		if gag.marker_id == &"poster_permit_queue":
			queue = gag
	# The east Clerk patrols (17.5, 8.5)-(17.5, 13.5); move the queue just
	# inside, then just outside, R_vis of the nearer vertex along x.
	queue.position = Vector3(17.5 + radius - 0.05, 0.0, 8.5)
	assert_array(Array(MapValidator.check_clutter_placement({_SEGMENT_ID: map},
			OverworldConfig.new(), PresentationConfig.new()))).is_empty()
	queue.position = Vector3(17.5 + radius + 0.05, 0.0, 8.5)
	var errors: PackedStringArray = MapValidator.check_clutter_placement({_SEGMENT_ID: map},
			OverworldConfig.new(), PresentationConfig.new())
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("clutter 'poster_permit_queue'")


func _segment() -> OverworldMap:
	return auto_free((load("res://data/maps/paris_segment_placeholder.tscn") as PackedScene).instantiate())
