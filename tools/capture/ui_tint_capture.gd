extends SceneTree
## AC-53 (story sprite-camera-presentation 057, TR-presentation-024): the UI
## layer is never tinted by the world's tonemapper. Boots `BattleMode` with
## the shipped squad and the real content boot (as `battle_capture.gd`) into
## each AC-53 scene, freezes it and diffs the final presented frame against
## the UI layer rendered alone, on every pixel where the UI is opaque:
##
##   battle_menu          Battle, the command menu up (squad turn);
##   battle_numbers       Battle, the frame a beat ends (damage numbers);
##   boss_bureaucratia    the shipped Bureaucratia boss fight, its takeover
##                        played out (the light ends on `boss_bureaucratia`);
##   boss_megacorp        a MegaCorp boss fight (no shipped encounter yet),
##                        its takeover played out;
##   defeat               the Defeat light with the Defeat banner and the
##                        Defeat Prompt card on GameRoot's overlay layer;
##   victory_peak         the frame the Victory blend completes.
##
## The UI alone is the frame with 3D disabled and the world's backdrop canvas
## hidden, rendered twice, over black and over white: the opaque mask is where
## both agree (`CaptureChecks.ui_opaque_mask`), and the over-black render is
## the UI-alone reference. Each scene is measured three ways:
##
##   shipped      the game's own environment                -> must PASS;
##   world_agx    the world tonemapped by AgX with the
##                scene profile's exposure / AgX settings   -> must PASS
##                (and the world's own pixels must move: the sensitivity
##                control proving the tonemapper is live);
##   ui_through_world  the negative control: the same AgX world with the UI
##                canvas layers pulled into the 3D background canvas, so the
##                UI goes through the world's tonemapper    -> must FAIL.
##
## Needs a window and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/ui_tint_capture.gd [-- --size=1920x1080 --out=res://dir/]
##
## Writes per scene `<scene>_final.png`, `<scene>_ui_alone.png`,
## `<scene>_ui_mask.png`, `<scene>_world_agx.png`,
## `<scene>_ui_through_world.png`, `<scene>_ui_through_world_fail.png` and
## one `measurements.json`. Exit 0 when every scene passes shipped and
## world_agx, every negative control fails and every sensitivity control
## responds; 1 otherwise.

const DEFAULT_OUT: String = "res://production/qa/evidence/ui-never-tinted/"
## Frames rendered after each setup change before reading back.
const SETTLE_FRAMES: int = 3
## GameRoot's `OverlayHost` canvas layer (`src/game_state/game_root.tscn`),
## where the Defeat Prompt is drawn in the game.
const OVERLAY_LAYER: int = 10
## The fixed step used to walk the Victory blend to its peak.
const VICTORY_STEP: float = 1.0 / 240.0
## Mean ΔE the world's own (non-UI) pixels must move under AgX for the
## sensitivity control to count as responding.
const SENSITIVITY_MIN_MEAN: float = 1.0

## [scene, encounter id ("" = ad-hoc MegaCorp boss), what to do, profile].
const SCENES: Array = [
	["battle_menu", "enc_paris_clerks_hall", "menu", "battle"],
	["battle_numbers", "enc_paris_clerks_hall", "numbers", "battle"],
	["boss_bureaucratia", "enc_paris_supervisor", "menu", "boss_bureaucratia"],
	["boss_megacorp", "", "menu", "boss_megacorp"],
	["defeat", "enc_paris_clerks_hall", "defeat", "defeat"],
	["victory_peak", "enc_paris_clerks_hall", "victory", "victory"],
]
## The ad-hoc MegaCorp boss fight (as `battle_capture.gd --faction=...`).
const MEGACORP_ENEMIES: Array[String] = ["enemy_ceo", "enemy_security_drone"]
const MEGACORP_FACTION: String = "faction_megacorp"

var _catalog: ContentCatalogService = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var out_dir: String = String(args.get("out", DEFAULT_OUT))
	var dims: PackedStringArray = String(args.get("size", "1920x1080")).split("x")
	var size := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(size)
	root.size = size
	# No stray mouse hover may change a button between passes.
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var m: Dictionary = {"tool": "tools/capture/ui_tint_capture.gd", "ac": "AC-53",
			"size": [size.x, size.y],
			"limit": {"max_delta_e": CaptureChecks.UI_TINT_DELTA_E_MAX, "over": "every opaque UI pixel",
					"opaque": "UI alone over black == over white within %d/255 per channel" % CaptureChecks.UI_OPAQUE_TOLERANCE},
			"scenes": {}}
	var all_pass: bool = true
	var all_neg_fail: bool = true
	var all_sensitive: bool = true
	for row: Array in SCENES:
		var scene: String = row[0]
		var mode: BattleMode = await _boot_scene(String(row[1]), String(row[2]))
		if mode == null:
			printerr("ui_tint_capture: %s: boot failed" % scene)
			quit(1)
			return
		var entry: Dictionary = await _measure(mode, scene, String(row[3]), out_dir)
		m["scenes"][scene] = entry
		all_pass = all_pass and bool(entry["shipped"]["pass"]) and bool(entry["world_agx"]["pass"])
		all_neg_fail = all_neg_fail and not bool(entry["ui_through_world"]["pass"])
		all_sensitive = all_sensitive and bool(entry["sensitivity_control"]["responds"])
		print("ui_tint_capture: %s shipped %s (max %.2f), world_agx %s (max %.2f), ui_through_world %s (max %.2f)" % [
				scene, _word(entry["shipped"]), float(entry["shipped"]["stats"]["max"]),
				_word(entry["world_agx"]), float(entry["world_agx"]["stats"]["max"]),
				_word(entry["ui_through_world"]), float(entry["ui_through_world"]["stats"]["max"])])
		await _free_mode(mode)
	m["pass"] = all_pass
	m["negative_control_discriminates"] = all_neg_fail
	m["sensitivity_control_responds"] = all_sensitive
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir.path_join("measurements.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", true))
	f.close()
	print("ui_tint_capture: AC-53 %s; negative control %s; sensitivity %s; wrote %s" % [
			"PASS" if all_pass else "FAIL", "FAILS as expected" if all_neg_fail else "DID NOT FAIL",
			"responds" if all_sensitive else "DID NOT RESPOND", out_dir])
	quit(0 if all_pass and all_neg_fail and all_sensitive else 1)


## Measures one frozen scene: final vs UI alone under the shipped
## environment, under the AgX world, and under the negative-control fixture.
func _measure(mode: BattleMode, scene: String, profile_id: String, out_dir: String) -> Dictionary:
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	var shipped_env: Environment = stage.world_environment.environment
	var profile: LightingProfile = _resolve_profile(StringName(profile_id))
	var backdrop: CanvasLayer = mode.get_node(^"BackdropLayer") as CanvasLayer

	var final: Image = await _grab()
	_save(final, out_dir, "%s_final" % scene)
	# The UI layer alone: 3D off, the world's backdrop canvas hidden, over
	# black then over white.
	var old_clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)
	backdrop.visible = false
	root.disable_3d = true
	RenderingServer.set_default_clear_color(Color.BLACK)
	var ui_black: Image = await _grab()
	RenderingServer.set_default_clear_color(Color.WHITE)
	var ui_white: Image = await _grab()
	RenderingServer.set_default_clear_color(old_clear)
	root.disable_3d = false
	backdrop.visible = true
	var opaque: Dictionary = CaptureChecks.ui_opaque_mask(ui_black, ui_white)
	var mask: Image = opaque["image"]
	_save(ui_black, out_dir, "%s_ui_alone" % scene)
	_save(mask, out_dir, "%s_ui_mask" % scene)

	var entry: Dictionary = {"profile": profile_id, "opaque_ui_pixels": opaque["pixels"],
			"profile_on_stage_blend_p": stage.blend_p()}
	entry["shipped"] = _judge(final, ui_black, mask)
	entry["shipped"]["environment"] = {"tonemap_mode": shipped_env.tonemap_mode,
			"background_canvas_max_layer": shipped_env.background_canvas_max_layer}

	# The world under AgX, the UI left where the game draws it.
	stage.world_environment.environment = UiTintFixture.world_agx(shipped_env, profile)
	var agx: Image = await _grab()
	_save(agx, out_dir, "%s_world_agx" % scene)
	entry["world_agx"] = _judge(agx, ui_black, mask)
	entry["world_agx"]["environment"] = {"tonemap_mode": "AGX", "exposure": profile.exposure,
			"agx_white": profile.agx_white, "agx_contrast": profile.agx_contrast}
	# Sensitivity: the world's own pixels (everything not opaque UI) move.
	var world_px: Image = _inverted(mask)
	var sens: Dictionary = CaptureChecks.masked_delta_e(final, agx, world_px)
	entry["sensitivity_control"] = {"fixture": "world pixels, shipped vs AgX", "stats": sens,
			"min_mean": SENSITIVITY_MIN_MEAN, "responds": float(sens["mean"]) >= SENSITIVITY_MIN_MEAN}

	# Negative control: the UI routed through the world's tonemapper.
	stage.world_environment.environment = UiTintFixture.ui_through_world(shipped_env, profile, OVERLAY_LAYER)
	var routed: Image = await _grab()
	_save(routed, out_dir, "%s_ui_through_world" % scene)
	entry["ui_through_world"] = _judge(routed, ui_black, mask)
	entry["ui_through_world"]["fixture"] = "AgX world, background_canvas_max_layer = %d" % OVERLAY_LAYER
	var fail_map: Dictionary = CaptureChecks.delta_e_failure_map(routed, ui_black, mask,
			CaptureChecks.UI_TINT_DELTA_E_MAX)
	_save(fail_map["image"], out_dir, "%s_ui_through_world_fail" % scene)
	entry["ui_through_world"]["failing_pixels"] = fail_map["pixels"]
	stage.world_environment.environment = shipped_env
	return entry


func _judge(frame: Image, ui_alone: Image, mask: Image) -> Dictionary:
	var stats: Dictionary = CaptureChecks.masked_delta_e(frame, ui_alone, mask)
	var v: Dictionary = CaptureChecks.ui_tint_verdict(stats)
	return {"pass": v["pass"], "failures": v["failures"], "stats": stats}


## Boots `BattleMode` into one AC-53 scene and freezes it there.
## `what`: `menu` (squad turn), `numbers` (a beat's end), `defeat`, `victory`.
func _boot_scene(enc_id: String, what: String) -> BattleMode:
	var mode: BattleMode = _boot_battle(enc_id)
	if mode == null:
		return null
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	match what:
		"numbers":
			var ended: Array[bool] = [false]
			mode.replay.beat_finished.connect(func(_p: BeatPlan) -> void: ended[0] = true, CONNECT_ONE_SHOT)
			for action: int in 2:
				mode.handle_action(InputActions.CONFIRM, true)
				mode.handle_action(InputActions.CONFIRM, false)
			var guard: int = 0
			while not ended[0] and guard < 600:
				await process_frame
				guard += 1
		"defeat":
			DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.DEFEAT)
			mode.settle_replay()
			# GameRoot's overlay layer with the Defeat Prompt card on it.
			var host := CanvasLayer.new()
			host.name = "OverlayHost"
			host.layer = OVERLAY_LAYER
			var prompt: DefeatPrompt = (load("res://src/game_state/overlays/defeat_prompt.tscn") as PackedScene).instantiate()
			var payload := DefeatPromptPayload.new()
			payload.offers_retreat = true
			prompt.setup(null, payload)
			host.add_child(prompt)
			mode.add_child(host)
			for i: int in 30:
				await process_frame
		"victory":
			DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.VICTORY)
			# Walk the clock to the frame the Victory blend completes.
			mode.set_process(false)
			var guard: int = 0
			while guard < 100000:
				mode.step_replay(VICTORY_STEP)
				guard += 1
				if mode._end_hold_left >= 0.0 \
						and mode._end_hold_clock() >= mode.presentation_config.blend_victory:
					break
			for i: int in 5:
				await process_frame
	# Frozen from here: no idle frame, blend or tween moves between passes.
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	return mode


## Boots `BattleMode` with the shipped squad (the real content boot, as
## `battle_capture.gd`), Battle light applied. `enc_id` "" builds the ad-hoc
## MegaCorp boss fight. The content boot runs once per run (a second boot
## of the same catalog is refused). Null on failure.
func _boot_battle(enc_id: String) -> BattleMode:
	if _catalog == null:
		_catalog = _boot_content()
	if _catalog == null:
		return null
	var catalog: ContentCatalogService = _catalog
	var d := EncounterDescriptor.new()
	if enc_id.is_empty():
		d.encounter_id = "adhoc_megacorp_boss"
		d.enemy_ids = PackedStringArray(MEGACORP_ENEMIES)
		d.faction_id = MEGACORP_FACTION
		d.is_boss = true
	else:
		var rec: EncounterData = catalog.get_record(&"encounter", enc_id) as EncounterData
		if rec == null:
			printerr("ui_tint_capture: unknown encounter %s" % enc_id)
			return null
		d.encounter_id = rec.id
		d.enemy_ids = rec.enemy_ids
		d.battle_stage_id = rec.battle_stage_id
		d.faction_id = rec.faction_id
		d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(catalog)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	root.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	return mode


## The real content boot (sprite-set validators included, ADR-0005 §9).
func _boot_content() -> ContentCatalogService:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(catalog)
	if boot == null or catalog.state != ContentCatalogService.State.READY:
		printerr("ui_tint_capture: content boot failed: %s" % [catalog.report])
		return null
	return catalog


func _free_mode(mode: BattleMode) -> void:
	root.remove_child(mode)
	mode.free()
	for i: int in 3:
		await process_frame


## An L8 mask with white and black swapped.
static func _inverted(mask: Image) -> Image:
	var c: Image = mask.duplicate() as Image
	c.convert(Image.FORMAT_L8)
	var d: PackedByteArray = c.get_data()
	for i: int in d.size():
		d[i] = 255 - d[i]
	return Image.create_from_data(c.get_width(), c.get_height(), false, Image.FORMAT_L8, d)


static func _word(v: Dictionary) -> String:
	return "PASS" if bool(v["pass"]) else "FAIL"


func _save(img: Image, out_dir: String, file_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join("%s.png" % file_name)))


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile
