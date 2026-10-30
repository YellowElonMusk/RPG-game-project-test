extends SceneTree
## Adds the Paris segment's optional pocket and payoff tells (story 051,
## GDD rule 7a) to `data/maps/paris_segment_placeholder.tscn` in place: the
## segment is hand-authored, not generated, so this edits its walk layer
## and markers and re-saves it. Idempotent: re-running replaces the nodes
## it owns and rewrites the same cells.
##
## The archive courtyard: a 3 x 3 dead-end room in the south-east corner
## (cells x 20-22, rows 12-14), walled on row 11 and column 19, entered
## through a gate at (20, 11) that the east Clerk's `open` payoff opens. It
## holds a `change` gag with a recruit remark. The west Clerk's `clue` tell
## is a rolled poster beside its patrol.
##
## Usage: godot --headless --path . -s res://tools/maps/build_segment_pocket.gd

const _SCENE: String = "res://data/maps/paris_segment_placeholder.tscn"
const _WALLS: Array[Vector2i] = [Vector2i(19, 11), Vector2i(21, 11), Vector2i(22, 11),
		Vector2i(19, 12), Vector2i(19, 13), Vector2i(19, 14)]
const _OWNED: Array[String] = ["ArchiveCourtyardGate", "GagArchiveCourtyard", "TellWestPoster"]


func _initialize() -> void:
	var map: OverworldMap = (load(_SCENE) as PackedScene).instantiate() as OverworldMap
	for n: String in _OWNED:
		var old: Node = map.get_node_or_null(n)
		if old != null:
			map.remove_child(old)
			old.free()
	for c: Vector2i in _WALLS:
		map.walk_layer.set_cell(c, 0, Vector2i(1, 0))
	map.walk_layer.set_cell(Vector2i(20, 11), 0, Vector2i(0, 0))
	var gate := CheckpointMarker.new()
	gate.name = "ArchiveCourtyardGate"
	gate.marker_id = &"cp_segment_pocket"
	gate.requirement_flag = "segment_pocket_unlatched"
	gate.obtained_at = "enc_paris_clerks_east"
	gate.failure_outcome = CheckpointMarker.FailureOutcome.REDIRECT
	gate.failure_line = "The courtyard gate is chained. A tag reads: ARCHIVE. FILED UNDER NO."
	gate.blocked_rect = Rect2(20, 11, 1, 1)
	gate.return_marker = Vector2(21.5, 9.5)
	gate.return_facing = Vector2.UP
	_place(map, gate, Vector2(20.5, 11.5))
	var gag := GagInteractable.new()
	gag.name = "GagArchiveCourtyard"
	gag.marker_id = &"gag_archive_courtyard"
	gag.response = GagInteractable.Response.CHANGE
	gag.text = "You tip over a filing cabinet. Forty years of permits to apply for permits slide out."
	gag.recruit_remark = "remark_paris_archive_courtyard"
	_place(map, gag, Vector2(21.5, 13.5))
	var tell := GagInteractable.new()
	tell.name = "TellWestPoster"
	tell.marker_id = &"tell_west_poster"
	tell.text = "A rolled-up poster sticks out of the Clerk's in-tray."
	tell.payoff_tell = "enc_paris_clerks_west"
	_place(map, tell, Vector2(13.5, 5.5))
	var scene := PackedScene.new()
	var err: Error = scene.pack(map)
	if err == OK:
		err = ResourceSaver.save(scene, _SCENE)
	print("build_segment_pocket: ", "wrote " + _SCENE if err == OK else "failed (%d)" % err)
	map.free()
	quit(0 if err == OK else 1)


func _place(map: OverworldMap, marker: Node3D, at: Vector2) -> void:
	marker.position = Vector3(at.x, 0.0, at.y)
	map.add_child(marker)
	marker.owner = map
