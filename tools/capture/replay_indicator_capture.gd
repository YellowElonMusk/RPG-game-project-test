extends SceneTree
## AC-69 (story sprite-camera-presentation 074, P-18): retained 1080p
## screenshots of the replay indicator in its three states, with keyboard and
## gamepad prompts, and of the refusal pulse on the command menu. Each is
## taken over Battle and over each faction's boss takeover. The WCAG
## contrast of the text against its own backing is measured from the
## captured pixels.
##
##   background         battle (enc_paris_clerks_hall), boss_bureaucratia
##                      (enc_paris_supervisor, takeover played),
##                      boss_megacorp (ad-hoc CEO fight, takeover played)
##   indicator states   active, latched (a Confirm during the replay),
##                      passive (the replay walked on to the first frame
##                      where no press would change anything)
##   prompts            keyboard; gamepad (Xbox face names)
##   refusal pulse      the command menu's focused button, captured near the
##                      pulse's peak (Reduce Motion off)
##
## Contrast per shot: the backing is the median colour of an inset ring just
## inside the widget's border; the text colour is the label-rect pixel that
## contrasts most with that backing; the ratio must be >= 4.5. Needs a
## window and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/replay_indicator_capture.gd [-- --out=res://dir/]
##
## Writes `<background>_<state>_<device>.png`, `<background>_refusal_pulse.png`
## and `measurements.json`. Exit 0 iff every shot is valid and passes.

const DEFAULT_OUT: String = "res://production/qa/evidence/replay-indicator-refusal-pulse/"
const SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 3
## Mode-time step used to walk a replay to its passive frame.
const WALK_STEP: float = 1.0 / 120.0
const WALK_CAP: int = 20000
## Pixels inside the widget's border sampled for its backing.
const BACKING_INSET: int = 5
const MEGACORP_ENEMIES: Array[String] = ["enemy_ceo", "enemy_security_drone"]
const MEGACORP_FACTION: String = "faction_megacorp"
## [background, encounter id ("" = ad-hoc MegaCorp boss)].
const BACKGROUNDS: Array = [
	["battle", "enc_paris_clerks_hall"],
	["boss_bureaucratia", "enc_paris_supervisor"],
	["boss_megacorp", ""],
]

var _catalog: ContentCatalogService = null
var _bindings: InputBindings = null
var _out_dir: String = DEFAULT_OUT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_dir = a.substr(6)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_bindings = load(BattleMode.BINDINGS_PATH) as InputBindings
	_catalog = _boot_content()
	if _catalog == null:
		quit(1)
		return
	var m: Dictionary = {"tool": "tools/capture/replay_indicator_capture.gd", "ac": "AC-69",
			"size": [SIZE.x, SIZE.y], "min_ratio": WcagContrast.AA_TEXT, "shots": {}}
	var all_pass: bool = true
	for bg: Array in BACKGROUNDS:
		var name: String = bg[0]
		for state: StringName in [ReplayInputRouter.INDICATOR_ACTIVE, ReplayInputRouter.INDICATOR_LATCHED,
				ReplayInputRouter.INDICATOR_PASSIVE]:
			var mode: BattleMode = await _boot(String(bg[1]))
			if mode == null:
				quit(1)
				return
			var reached: bool = await _reach_state(mode, state)
			for device: StringName in [PromptGlyphs.DEVICE_KEY, PromptGlyphs.DEVICE_PAD]:
				var shot: String = "%s_%s_%s" % [name, state, device]
				var entry: Dictionary = {"state_reached": reached}
				if reached:
					var indicator: ReplayIndicator = mode.replay_indicator()
					indicator.glyphs = PromptGlyphs.new(_bindings, device, &"xbox")
					indicator.refresh_text()
					entry.merge(await _shoot(indicator, indicator.get_child(0) as Control, shot))
					entry["text"] = indicator.text_for(state)
				entry["pass"] = reached and bool(entry.get("pass", false))
				all_pass = all_pass and bool(entry["pass"])
				m["shots"][shot] = entry
				print("replay_indicator_capture: %s %s ratio %.2f" % [shot,
						"PASS" if entry["pass"] else "FAIL", float(entry.get("ratio", 0.0))])
			await _free(mode)
		# The refusal pulse on the command menu's focused button.
		var menu_mode: BattleMode = await _boot(String(bg[1]))
		var pulse: Dictionary = await _pulse_shot(menu_mode, "%s_refusal_pulse" % name)
		all_pass = all_pass and bool(pulse["pass"])
		m["shots"]["%s_refusal_pulse" % name] = pulse
		print("replay_indicator_capture: %s_refusal_pulse %s ratio %.2f offset %.2f px" % [name,
				"PASS" if pulse["pass"] else "FAIL", float(pulse.get("ratio", 0.0)),
				float(pulse.get("pulse_offset_px", 0.0))])
		await _free(menu_mode)
	m["pass"] = all_pass
	var f := FileAccess.open(ProjectSettings.globalize_path(_out_dir.path_join("measurements.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", true))
	f.close()
	print("replay_indicator_capture: AC-69 %s; wrote %s" % ["PASS" if all_pass else "FAIL", _out_dir])
	quit(0 if all_pass else 1)


## Plays the reveal (and a boss's takeover), submits Attack on the first
## target, then walks the replay until the indicator shows `state`.
func _reach_state(mode: BattleMode, state: StringName) -> bool:
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	mode.step_replay(0.0)
	if state == ReplayInputRouter.INDICATOR_LATCHED:
		mode.handle_action(InputActions.CONFIRM, true)
		mode.handle_action(InputActions.CONFIRM, false)
	var indicator: ReplayIndicator = mode.replay_indicator()
	var n: int = 0
	while indicator.current_state() != state and n < WALK_CAP:
		mode.step_replay(WALK_STEP)
		n += 1
		if indicator.current_state() == ReplayInputRouter.INDICATOR_HIDDEN:
			return false
	return indicator.current_state() == state


func _pulse_shot(mode: BattleMode, shot: String) -> Dictionary:
	var focused: Control = mode.get_viewport().gui_get_focus_owner()
	if focused == null:
		return {"pass": false, "error": "no focused command button"}
	var config: UiConfig = load(UiConfig.DEFAULT_PATH) as UiConfig
	mode.process_mode = Node.PROCESS_MODE_INHERIT
	RefusalPulse.play(focused, config, false)
	# The first quarter of the pulse travels out to +px: grab near its peak.
	await create_timer(config.refusal_pulse_time / 4.0).timeout
	var entry: Dictionary = await _shoot(focused, focused, shot)
	entry["pulse_offset_px"] = focused.offset_transform_position.x
	entry["focused"] = (focused as Button).text if focused is Button else focused.name
	entry["pass"] = bool(entry["pass"]) and absf(float(entry["pulse_offset_px"])) > 0.0
	return entry


## Freezes `mode`, grabs the frame, saves it and measures `widget`'s text
## against its own backing.
func _shoot(widget: Control, text_rect_node: Control, shot: String) -> Dictionary:
	var mode: Node = widget.get_parent()
	while mode != null and not (mode is BattleMode):
		mode = mode.get_parent()
	if mode != null:
		mode.process_mode = Node.PROCESS_MODE_DISABLED
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out_dir.path_join("%s.png" % shot)))
	var scale: Vector2 = Vector2(img.get_size()) / root.get_visible_rect().size
	var full: Rect2 = Rect2(widget.get_global_rect().position * scale, widget.get_global_rect().size * scale)
	if not Rect2(Vector2.ZERO, Vector2(img.get_size())).grow(0.5).encloses(full):
		# A clipped widget is an invalid shot, never a pass: measuring the
		# visible sliver once passed an indicator pushed off the screen.
		return {"pass": false, "error": "widget not fully on screen",
				"rect": [full.position.x, full.position.y, full.size.x, full.size.y]}
	var box: Rect2i = _to_px(widget.get_global_rect(), scale, img)
	var text_box: Rect2i = _to_px(text_rect_node.get_global_rect(), scale, img)
	if box.size.x <= BACKING_INSET * 2 or box.size.y <= BACKING_INSET * 2:
		return {"pass": false, "error": "widget too small", "rect": [box.position.x, box.position.y, box.size.x, box.size.y]}
	var backing: Color = _median_ring(img, box.grow(-BACKING_INSET))
	var text: Color = backing
	var best: float = 1.0
	for y: int in range(text_box.position.y, text_box.end.y):
		for x: int in range(text_box.position.x, text_box.end.x):
			var c: Color = img.get_pixel(x, y)
			var r: float = WcagContrast.ratio(c, backing)
			if r > best:
				best = r
				text = c
	return {"pass": best >= WcagContrast.AA_TEXT, "ratio": snappedf(best, 0.01),
			"backing": backing.to_html(false), "text_colour": text.to_html(false),
			"rect": [box.position.x, box.position.y, box.size.x, box.size.y]}


func _to_px(r: Rect2, scale: Vector2, img: Image) -> Rect2i:
	var p := Rect2i(Vector2i((r.position * scale).floor()), Vector2i((r.size * scale).ceil()))
	return p.intersection(Rect2i(Vector2i.ZERO, img.get_size()))


## The median colour (by luminance) of the one-pixel ring on `r`'s edge.
func _median_ring(img: Image, r: Rect2i) -> Color:
	var px: Array[Color] = []
	for x: int in range(r.position.x, r.end.x):
		px.append(img.get_pixel(x, r.position.y))
		px.append(img.get_pixel(x, r.end.y - 1))
	for y: int in range(r.position.y, r.end.y):
		px.append(img.get_pixel(r.position.x, y))
		px.append(img.get_pixel(r.end.x - 1, y))
	px.sort_custom(func(a: Color, b: Color) -> bool: return WcagContrast.luminance(a) < WcagContrast.luminance(b))
	return px[px.size() / 2]


func _boot(enc_id: String) -> BattleMode:
	var d := EncounterDescriptor.new()
	if enc_id.is_empty():
		d.encounter_id = "adhoc_megacorp_boss"
		d.enemy_ids = PackedStringArray(MEGACORP_ENEMIES)
		d.faction_id = MEGACORP_FACTION
		d.is_boss = true
	else:
		var rec: EncounterData = _catalog.get_record(&"encounter", enc_id) as EncounterData
		d.encounter_id = rec.id
		d.enemy_ids = rec.enemy_ids
		d.battle_stage_id = rec.battle_stage_id
		d.faction_id = rec.faction_id
		d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(_catalog)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	root.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	mode.set_process(false)
	for i: int in 30:
		await process_frame
	mode.settle_replay()  # the reveal, and a boss's takeover
	for i: int in 10:
		await process_frame
	return mode


func _boot_content() -> ContentCatalogService:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(catalog)
	if boot == null or catalog.state != ContentCatalogService.State.READY:
		printerr("replay_indicator_capture: content boot failed: %s" % [catalog.report])
		return null
	return catalog


func _free(mode: BattleMode) -> void:
	root.remove_child(mode)
	mode.free()
	for i: int in 3:
		await process_frame


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile
