extends SceneTree
## Walk-in visibility captures (GDD rule 12 "Visibility"; story 087, with
## the parts of stories 134 and 135 it needs). For every patrolling symbol
## on every shipped map, for each of its approaches (`PatrolApproaches`):
## freeze the symbol at the patrol point nearest the approach, put the
## (hidden) party at `see_m + 0.1 m` from it, snap the camera there and
## render four passes:
##   0. background only (set and symbol hidden);
##   1. the symbol alone -> its sprite mask (pixels differing from pass 0);
##   2. set and symbol (retained as the screenshot);
##   3. set without the symbol.
## The symbol's visible share is the masked pixels where passes 2 and 3
## differ (set occluders only: the party, other symbols and HUD labels are
## hidden in every pass). A share under 50% fails.
##
## Usage (needs a window, not --headless):
##
##   godot --path . -s res://tools/level_review/walkin_capture.gd
##
## Writes `production/qa/evidence/story-087-patrol-visibility/` (one PNG per
## approach plus `report.md`). Exit 0 when every approach is at least 50%
## visible, 1 otherwise.

const OUT_DIR: String = "res://production/qa/evidence/story-087-patrol-visibility/"
const MODE_SCENE: String = "res://src/overworld/overworld_mode.tscn"
const MAPS: Array[String] = ["map_paris_town_placeholder", "map_paris_segment_placeholder",
		"map_paris_dungeon_placeholder", "map_paris_boss_chamber_placeholder"]
const MIN_VISIBLE: float = 0.5
## Frames rendered after each change before reading the viewport back.
const SETTLE_FRAMES: int = 3
## Images are compared at 1 / COMPARE_DIV size, for speed.
const COMPARE_DIV: int = 2

var _jobs: Array = []  # [map_id, symbol_index, Approach]
var _job: int = -1
var _pass: int = -1
var _wait: int = 0
var _mode: OverworldMode = null
var _view: OverworldView = null
var _images: Array[Image] = []
var _rows: Array[String] = []
var _failures: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var cfg := OverworldConfig.new()
	for map_id: String in MAPS:
		var path: String = OverworldMap.scene_path(map_id, cfg.map_scene_dir)
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		var markers: Array[EncounterSymbol] = map.symbol_markers()
		for i: int in markers.size():
			for a: PatrolApproaches.Approach in PatrolApproaches.of(map, markers[i], cfg):
				_jobs.append([map_id, i, a])
		map.free()
	print("walkin_capture: %d approach(es)" % _jobs.size())


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _pass >= 0:
		_images.append(root.get_viewport().get_texture().get_image())
		if _pass < 3:
			_pass += 1
			_apply_pass()
			return false
		_finish_job()
	_job += 1
	if _job >= _jobs.size():
		_write_report()
		quit(1 if _failures > 0 else 0)
		return true
	_start_job()
	return false


func _start_job() -> void:
	var job: Array = _jobs[_job]
	if _mode == null or _mode.get_map().map_id != job[0]:
		if _mode != null:
			_mode.queue_free()
		_mode = (load(MODE_SCENE) as PackedScene).instantiate() as OverworldMode
		_mode.setup(null, MapEntryPayload.new(job[0], &""))
		_mode.set_process(false)
		root.add_child(_mode)
		_view = _mode.get_node(^"OverworldView") as OverworldView
	_images.clear()
	_pass = 0
	_apply_pass()


## Sets up pass `_pass` for the current job, then waits a few frames.
func _apply_pass() -> void:
	var job: Array = _jobs[_job]
	var a: PatrolApproaches.Approach = job[2]
	var brains: Array[SymbolBrain] = _mode.get_symbol_brains()
	var target: SymbolBrain = null
	for b: SymbolBrain in brains:
		if b.marker_index == int(job[1]):
			target = b
	target.position = a.symbol_at
	_mode.set_leader_position(a.leader_at)
	if _view.get_camera() != null:
		_view.get_camera().snap_to(a.leader_at)
	_view._process(0.0)
	_view.leader_sprite.visible = false
	for f: CharacterSprite in _view.follower_sprites:
		f.visible = false
	var prompt: Node = _view.get_node_or_null(^"PromptLayer")
	if prompt != null:
		prompt.visible = false
	var sprites: Dictionary = _view.get_symbol_sprites()
	for b: SymbolBrain in sprites:
		(sprites[b] as Node3D).visible = b == target and (_pass == 1 or _pass == 2)
	var set_node: Node3D = _mode.get_map().get_node_or_null(^"PlaceholderSet") as Node3D
	if set_node != null:
		set_node.visible = _pass >= 2
	_wait = SETTLE_FRAMES


func _finish_job() -> void:
	var job: Array = _jobs[_job]
	var a: PatrolApproaches.Approach = job[2]
	var small: Array[Image] = []
	for img: Image in _images:
		var s: Image = img.duplicate() as Image
		s.resize(img.get_width() / COMPARE_DIV, img.get_height() / COMPARE_DIV, Image.INTERPOLATE_NEAREST)
		small.append(s)
	var mask: int = 0
	var seen: int = 0
	var clipped: bool = false
	var last_x: int = small[0].get_width() - 1
	for y in small[0].get_height():
		for x in small[0].get_width():
			if not small[1].get_pixel(x, y).is_equal_approx(small[0].get_pixel(x, y)):
				mask += 1
				clipped = clipped or x == 0 or x == last_x
				if not small[2].get_pixel(x, y).is_equal_approx(small[3].get_pixel(x, y)):
					seen += 1
	var share: float = float(seen) / float(mask) if mask > 0 else 0.0
	var sym_id: String = "symbol_%d" % int(job[1])
	for m: EncounterSymbol in _mode.get_map().symbol_markers():
		if _mode.get_map().symbol_markers().find(m) == int(job[1]):
			sym_id = m.symbol_id if not m.symbol_id.is_empty() else m.encounter_id
	var file: String = "%s__%s__s%d.png" % [String(job[0]).trim_prefix("map_"), sym_id, a.sector]
	_images[2].save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	var ok: bool = mask > 0 and share >= MIN_VISIBLE
	if not ok:
		_failures += 1
	# Observation only: a mask touching the frame edge is camera framing
	# (AC-39, story 099), not a set occluder.
	_rows.append("| %s | %s | %d | %s | %.0f%% | %s | %s | `%s` |" % [job[0], sym_id, a.sector * 45,
			a.entry_cell, share * 100.0, "pass" if ok else "FAIL", "yes" if clipped else "", file])
	print("walkin_capture: %s %s sector %d: %.0f%% visible (%d mask px)" % [job[0], sym_id, a.sector, share * 100.0, mask])
	_pass = -1


func _write_report() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR + "report.md"), FileAccess.WRITE)
	f.store_line("# Patrol walk-in visibility (story 087)")
	f.store_line("")
	f.store_line("Generated by `tools/level_review/walkin_capture.gd`. Each row is one approach: the symbol frozen at the patrol point nearest it, the leader at `see_m + 0.1 m`. Visible share = the symbol's sprite-mask pixels a set occluder does not cover (pass threshold %d%%). Party, other symbols and HUD hidden in every pass." % int(MIN_VISIBLE * 100.0))
	f.store_line("")
	f.store_line("| Map | Symbol | Approach (deg) | Entry cell | Visible | Result | Clipped by frame | Capture |")
	f.store_line("|---|---|---|---|---|---|---|---|")
	for r: String in _rows:
		f.store_line(r)
	f.store_line("")
	f.store_line("%d approach(es), %d failure(s)." % [_rows.size(), _failures])
	f.close()
