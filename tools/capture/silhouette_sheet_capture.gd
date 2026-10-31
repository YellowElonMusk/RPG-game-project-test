extends SceneTree
## Story 037's sheet (GDD sprite-camera-presentation AC-33, "Silhouette test";
## art bible Principle 1; ADR-0005 §1): every shipped character as a
## black-fill silhouette, squad in `back` facing (idle and `victory`), enemies
## in `front` facing (idle and attack), at battle height (`T` per texel at
## 1920x1080 with the shipped config) and as a 32 px thumbnail, plus the
## lineups of 6 the art director's reviewers pick from, and the 2-of-3
## lineup proxy (`SilhouetteLineupCheck`) per character at both sizes.
##
## Built from each set's `SpriteFrames` (`build_sprite_frames()`, the art as
## played) through rule 10's `resolve()`, so a `no_mirror` pose is never
## shader-flipped. No rendering: battle height is the frame at `T` per texel,
## which story 039 measured the screen draws exactly. Runs headless:
##
##   godot --headless --path . -s res://tools/capture/silhouette_sheet_capture.gd [-- --out=res://dir/]
##
## Writes `silhouette_sheet.png`, `<set_id>.png` per character,
## `lineup_<set_id>.png` (with the answer key in `measurements.json`) and
## `measurements.json`. Exit 0 iff the proxy passes for every character at
## both sizes and no pose is missing. The AC-33 verdict stays the art director's.

const DEFAULT_OUT: String = "res://production/qa/evidence/story-037-silhouette-sheet-passes-the-lineup-test/"
## Space between silhouettes on the sheet, in pixels.
const GAP: int = 12
## The 32 px row is also shown enlarged this many times for reading.
const THUMB_VIEW_SCALE: int = 4
## Sizes the proxy is run at.
const SIZES: Array[String] = ["battle_height", "thumb_32"]


func _initialize() -> void:
	var out: String = DEFAULT_OUT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var cfg: PresentationConfig = PresentationValidators.load_config()
	var t: int = SpriteProjection.texel_scale(SilhouetteLineupCheck.SHEET_LINES, cfg.texel_base_lines)
	var r: Dictionary = build(PresentationValidators.load_sprite_sets(), t)
	var ok: bool = write(r, out) == OK
	var missing: int = 0
	for id: StringName in r["characters"]:
		missing += (r["characters"][id]["missing"] as PackedStringArray).size()
	for size: String in SIZES:
		print("silhouette_sheet_capture: %s %s %s" % [size,
				"PASS" if r["verdict"][size]["pass"] else "FAIL", r["verdict"][size]["failures"]])
	var passed: bool = ok and missing == 0 and r["verdict"]["battle_height"]["pass"] \
			and r["verdict"]["thumb_32"]["pass"]
	print("silhouette_sheet_capture: %s -> %s" % ["PASS" if passed else "FAIL", out])
	quit(0 if passed else 1)


## Every character of `sets` (id -> `SpriteSetData`) at texel scale `t`:
## `{"t", "characters": {id: {...}}, "verdict": {size: roster_verdict + "per"}}`.
## Per character: `is_squad`, `facing`, `poses`, `mirrored`, `missing`,
## `shown` (labels of the sheet cells), `reference_frame`, `battle_height`
## and `thumb` (the sheet cells' masks at each size).
static func build(sets: Dictionary, t: int) -> Dictionary:
	var chars: Dictionary = {}
	var gallery: Dictionary = {"battle_height": {}, "thumb_32": {}}
	var probes: Dictionary = {}
	var ids: Array = sets.keys()
	ids.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	for id: StringName in ids:
		var s: SpriteSetData = sets[id]
		var p: Dictionary = SilhouetteLineupCheck.pose_frames(s)
		var c: Dictionary = {"is_squad": s.is_squad, "facing": p["facing"], "poses": p["poses"],
				"mirrored": p["mirrored"], "missing": p["missing"], "shown": PackedStringArray(),
				"battle_height": [], "thumb": [], "reference_frame": null}
		var ref: Image = SilhouetteLineupCheck.reference_frame(p)
		var pr: Array[Image] = SilhouetteLineupCheck.probe_frames(p)
		if ref != null:
			c["reference_frame"] = ref
			var ref_mask: Image = SilhouetteLineupCheck.mask(ref)
			# Texel space: IoU of masks at T per texel equals IoU at 1 per texel.
			gallery["battle_height"][id] = ref_mask
			gallery["thumb_32"][id] = SilhouetteLineupCheck.thumbnail(ref_mask)
		var cells: Array[Image] = []
		var labels := PackedStringArray()
		if ref != null:
			cells.append(ref)
			labels.append("%s f0" % p["poses"][0])
		var second: Array = (p["frames"] as Dictionary).get(p["poses"][1], [])
		if not second.is_empty():
			cells.append(second[0])
			labels.append("%s f0" % p["poses"][1])
			cells.append(second[second.size() / 2])
			labels.append("%s f%d" % [p["poses"][1], second.size() / 2])
		for img: Image in cells:
			var m: Image = SilhouetteLineupCheck.mask(img)
			(c["battle_height"] as Array).append(SilhouetteLineupCheck.scaled(m, t))
			(c["thumb"] as Array).append(SilhouetteLineupCheck.thumbnail(m))
		c["shown"] = labels
		var pm: Dictionary = {"battle_height": [] as Array[Image], "thumb_32": [] as Array[Image]}
		for img: Image in pr:
			var m: Image = SilhouetteLineupCheck.mask(img)
			(pm["battle_height"] as Array[Image]).append(m)
			(pm["thumb_32"] as Array[Image]).append(SilhouetteLineupCheck.thumbnail(m))
		probes[id] = pm
		chars[id] = c
	var verdict: Dictionary = {}
	for size: String in SIZES:
		var per: Dictionary = {}
		for id: StringName in chars:
			per[id] = SilhouetteLineupCheck.character_verdict(probes[id][size], gallery[size], id)
		var v: Dictionary = SilhouetteLineupCheck.roster_verdict(per)
		v["per"] = per
		verdict[size] = v
	return {"t": t, "characters": chars, "verdict": verdict, "gallery": gallery}


## Writes the sheet, per-character images, lineups and `measurements.json`.
static func write(r: Dictionary, out: String) -> Error:
	var dir: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	var chars: Dictionary = r["characters"]
	var squad_cells: Array = []
	var enemy_cells: Array = []
	var thumb_cells: Array = []
	var thumb_view: Array = []
	var key: Dictionary = {}
	for id: StringName in chars:
		var c: Dictionary = chars[id]
		(squad_cells if c["is_squad"] else enemy_cells).append_array(c["battle_height"])
		thumb_cells.append_array(c["thumb"])
		for th: Image in c["thumb"]:
			thumb_view.append(SilhouetteLineupCheck.scaled(th, THUMB_VIEW_SCALE))
		var own: Image = SilhouetteLineupCheck.stack_rows([
				SilhouetteLineupCheck.compose_row(c["battle_height"], GAP),
				SilhouetteLineupCheck.compose_row(c["thumb"], GAP)])
		var err: Error = own.save_png(dir.path_join("%s.png" % id))
		if err != OK:
			return err
		# A reviewers' lineup: this character and the 5 others whose
		# reference silhouette is closest to its own, in id order.
		var lu: Dictionary = SilhouetteLineupCheck.lineup(r["gallery"]["battle_height"][id],
				r["gallery"]["battle_height"], id) if r["gallery"]["battle_height"].has(id) else {"lineup": []}
		var order: Array = (lu["lineup"] as Array).duplicate()
		order.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
		var row: Array = []
		for other: StringName in order:
			row.append(chars[other]["battle_height"][0])
		key[String(id)] = {"order": order.map(func(x: StringName) -> String: return String(x)),
				"answer": order.find(id) + 1}
		if not row.is_empty():
			err = SilhouetteLineupCheck.compose_row(row, GAP).save_png(dir.path_join("lineup_%s.png" % id))
			if err != OK:
				return err
	var sheet: Image = SilhouetteLineupCheck.stack_rows([
			SilhouetteLineupCheck.compose_row(squad_cells, GAP),
			SilhouetteLineupCheck.compose_row(enemy_cells, GAP),
			SilhouetteLineupCheck.compose_row(thumb_cells, GAP),
			SilhouetteLineupCheck.compose_row(thumb_view, GAP)])
	var e: Error = sheet.save_png(dir.path_join("silhouette_sheet.png"))
	if e != OK:
		return e
	var f := FileAccess.open(dir.path_join("measurements.json"), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report(r, key), "  "))
	f.close()
	return OK


## The JSON-safe summary of `build()`'s result and the lineup answer key.
static func report(r: Dictionary, key: Dictionary) -> Dictionary:
	var chars: Dictionary = {}
	for id: StringName in r["characters"]:
		var c: Dictionary = r["characters"][id]
		var row: Dictionary = {"role": "squad" if c["is_squad"] else "enemy", "facing": String(c["facing"]),
				"shown": Array(c["shown"]), "missing": Array(c["missing"]),
				"mirrored": c["mirrored"].keys().filter(func(k: StringName) -> bool: return c["mirrored"][k]).map(
						func(k: StringName) -> String: return String(k)),
				"battle_height_px": (c["battle_height"][0] as Image).get_size() if not (c["battle_height"] as Array).is_empty() else Vector2i.ZERO}
		for size: String in SIZES:
			var v: Dictionary = r["verdict"][size]["per"][id]
			var picks: Array = []
			for p: Dictionary in v["picks"]:
				picks.append({"picked": String(p["picked"]), "correct": p["correct"],
						"self_iou": snappedf(p["self_score"], 0.001), "closest_other": String(p["best_other"]),
						"closest_other_iou": snappedf(p["best_other_score"], 0.001),
						"lineup": (p["lineup"] as Array).map(func(x: StringName) -> String: return String(x))})
			row[size] = {"votes": v["votes"], "pass": v["pass"], "probes": picks}
		chars[String(id)] = row
	return {"tool": "tools/capture/silhouette_sheet_capture.gd", "ac": "AC-33", "story": "037",
			"t": r["t"], "sheet_lines": SilhouetteLineupCheck.SHEET_LINES,
			"proxy": {"reviewers": SilhouetteLineupCheck.REVIEWERS, "pass_votes": SilhouetteLineupCheck.PASS_VOTES,
				"lineup_size": SilhouetteLineupCheck.LINEUP_SIZE, "thumb_px": SilhouetteLineupCheck.THUMB_PX,
				"probes": "idle last frame; second pose (victory / attack) frames 0 and n/2",
				"reference": "idle frame 0", "metric": "IoU, feet-aligned; tie = wrong pick"},
			"verdict": {"battle_height": {"pass": r["verdict"]["battle_height"]["pass"],
					"failures": Array(r["verdict"]["battle_height"]["failures"])},
				"thumb_32": {"pass": r["verdict"]["thumb_32"]["pass"],
					"failures": Array(r["verdict"]["thumb_32"]["failures"])}},
			"lineup_answer_key": key, "characters": chars,
			"sheet_layout": "row 1 squad at battle height, row 2 enemies at battle height, row 3 every cell at 32 px (1:1), row 4 the same 32 px cells x4; characters in set-id order, cells per character as in `shown`"}
