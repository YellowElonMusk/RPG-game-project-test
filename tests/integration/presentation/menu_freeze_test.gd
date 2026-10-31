## Story 010 (GDD sprite-camera-presentation AC-8 [I]; ADR-0005 §4, §7;
## ADR-0002 §5): opening the Menu freezes every presentation clock, beat,
## punch and particle. A real Battle mode (`BattleModeHarness`: real
## `BattleCore`, view, HUD, replay controller and `GameStateMachine`) sits
## under a stand-in `ModeHost` that the stub loader disables exactly as
## `ModeHostSceneLoader` does, and real engine frames run, so every node,
## node-bound tween and particle in the mode is processed (or not) by the
## engine itself. A `PresentationDirector` with a recording sink writes the
## global uniforms every frame.
##
## Three cases, each frozen by opening the Menu: (a) mid-wind-up of a beat,
## (b) on the third frame of a running hit-punch, (c) mid-blend of a
## first-encounter boss takeover. Over 300 frames the probe (the sink's
## `mode_time`, every lighting value, the lens shift, every sprite's frame,
## the replay's state and clocks, the punch) is unchanged and no replay event
## fires; every particle reports it is not processing. On the frame after
## the Menu closes each value has moved by at most one `dt_max` step.
##
## The [C] half (pixel-identical main-viewport grabs) is the capture run's,
## not this suite's.
extends GdUnitTestSuite

const DT: float = BattleModeHarness.DT
const FROZEN_FRAMES: int = 300
const EPS: float = 1e-6
const _MODE_SCENES: Array[String] = [
	"res://src/battle/battle_mode.tscn",
	"res://src/overworld/overworld_mode.tscn",
	"res://src/game_state/modes/interim_camp_mode.tscn",
	"res://src/game_state/modes/title_mode.tscn",
	"res://src/game_state/modes/content_error_mode.tscn",
]


## Records every global the Director writes; never touches `RenderingServer`.
class RecordingSink extends GlobalUniformSink:
	var last: Dictionary = {}
	var writes: int = 0

	func set_global(name: StringName, value: Variant) -> void:
		last[name] = value
		writes += 1


var _sink: RecordingSink
var _host: Node


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


# --- Fixture -----------------------------------------------------------------

## A harness whose Battle mode lives under a stand-in `ModeHost`, plus a
## Director on a recording sink (outside the host, as under GameRoot/Services).
func _make(is_boss: bool) -> BattleModeHarness:
	_host = auto_free(Node.new())
	_host.name = "ModeHost"
	add_child(_host)
	var h := BattleModeHarness.create(_host, ChapterFlow.build_squad(BattleCatalog.shipped()), is_boss)
	auto_free(h.mode)
	h.loader.mode_host = _host
	_sink = RecordingSink.new()
	var director: PresentationDirector = auto_free(PresentationDirector.new())
	add_child(director)
	director.setup(h.machine, PresentationConfig.new(), _sink)
	h.reveal()
	return h


func _punch(h: BattleModeHarness) -> HitPunch:
	return h.mode.get(&"_hit_punch") as HitPunch


func _view(h: BattleModeHarness) -> BattleView:
	return h.mode.get_node(^"%BattleView") as BattleView


## One moving particle of each kind under the stage, plus one wrongly set to
## always process (the stage's explicit pause must still stop it).
func _add_particles(h: BattleModeHarness) -> Array[Node]:
	var gpu := GPUParticles3D.new()
	gpu.name = "FixtureGpuParticles"
	gpu.process_material = ParticleProcessMaterial.new()
	gpu.draw_pass_1 = QuadMesh.new()
	gpu.emitting = true
	var cpu := CPUParticles3D.new()
	cpu.name = "FixtureCpuParticles"
	cpu.mesh = QuadMesh.new()
	cpu.emitting = true
	var rogue := CPUParticles3D.new()
	rogue.name = "FixtureAlwaysParticles"
	rogue.mesh = QuadMesh.new()
	rogue.emitting = true
	rogue.process_mode = Node.PROCESS_MODE_ALWAYS
	var out: Array[Node] = [gpu, cpu, rogue]
	for p: Node in out:
		h.stage.add_child(p)
	return out


## Every value the AC names, as plain data (equal iff nothing moved).
func _probe(h: BattleModeHarness) -> Dictionary:
	var r: BattleReplayController = h.mode.replay
	var lighting: Dictionary = {}
	var values: LightingProfile = h.stage.current_values
	if values != null:
		for prop: Dictionary in values.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				lighting[prop["name"]] = values.get(StringName(prop["name"]))
	for light: DirectionalLight3D in [h.stage.key_light, h.stage.set_light, h.stage.fill_light]:
		if light != null:
			lighting[light.name] = [light.light_color, light.light_energy, light.rotation]
	var sprites: Dictionary = {}
	var view: BattleView = _view(h)
	for c: Combatant in h.mode.battle.squad + h.mode.battle.enemies:
		var s: CharacterSprite = view.get_sprite(c)
		if s != null:
			sprites[c.display_name + str(c.get_instance_id())] = [s.animation, s.frame]
	return {
		"mode_time": _sink.last.get(&"mode_time"),
		"rim": [_sink.last.get(&"actor_rim_color"), _sink.last.get(&"actor_rim_strength")],
		"lighting": lighting,
		"blend_p": h.stage.blend_p(),
		"lens_shift": h.stage.camera.frustum_offset,
		"punch_px": h.stage.punch_offset_px(),
		"punch_t": _punch(h).elapsed(),
		"sprites": sprites,
		"replay": [r.get_state(), r.get_windup_progress(), r.get_post_impact_time(),
				r.get_hold_time(), r.is_latched(), r.get_display_round()],
	}


## The particle nodes under `root`, any of the four kinds.
func _particles_under(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in root.find_children("*", "", true, false):
		if n is GPUParticles3D or n is CPUParticles3D or n is GPUParticles2D or n is CPUParticles2D:
			out.append(n)
	return out


## Opens the Menu, runs `FROZEN_FRAMES` real frames (ticking the machine
## alongside, as GameRoot does), and asserts nothing moved; then closes it,
## runs one frame and returns `[before, after]` probes for the bound checks.
func _freeze_and_release(h: BattleModeHarness) -> Array[Dictionary]:
	var fixtures: Array[Node] = _add_particles(h)
	assert_int(h.machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())).is_equal(
			GameStateMachine.RequestResult.OK)
	# The mode runs on real frames from here (the harness drove it by hand).
	h.mode.set_process(true)
	h.stage.set_process(true)
	assert_bool(h.stage.is_ambient_paused()).override_failure_message(
			"the Director did not pause the stage's ambience on overlay_opened(MENU)").is_true()
	h.machine.tick(DT)
	await get_tree().process_frame
	var frozen: Dictionary = _probe(h)
	assert_bool(frozen["mode_time"] != null).override_failure_message(
			"the Director wrote no mode_time global").is_true()
	if frozen["mode_time"] == null:
		return []
	var writes_before: int = _sink.writes
	var events_before: int = h.events.size()
	for i: int in FROZEN_FRAMES:
		h.machine.tick(DT)
		await get_tree().process_frame
		var now: Dictionary = _probe(h)
		if now != frozen:
			for key: String in frozen:
				assert_that(now[key]).override_failure_message(
						"'%s' moved on frozen frame %d" % [key, i]).is_equal(frozen[key])
			return []
	assert_int(_sink.writes).override_failure_message(
			"the Director stopped writing the globals under the Menu").is_greater(writes_before)
	assert_array(h.event_names_since(events_before)).override_failure_message(
			"a replay event fired under the Menu").is_empty()
	for p: Node in _particles_under(h.mode):
		assert_bool(p.can_process()).override_failure_message(
				"%s still processes under the Menu" % p.name).is_false()
	# Close: the next frame moves each value by at most one dt_max step.
	assert_int(h.machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)
	assert_bool(h.stage.is_ambient_paused()).is_false()
	for p: Node in fixtures:
		assert_bool(p.can_process()).override_failure_message(
				"%s did not resume after the Menu" % p.name).is_true()
	assert_int(fixtures[2].process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	h.machine.tick(DT)
	await get_tree().process_frame
	var after: Dictionary = _probe(h)
	var dt_max: float = h.mode.presentation_config.follow_camera_dt_max
	var dmt: float = float(after["mode_time"]) - float(frozen["mode_time"])
	assert_float(dmt).is_greater(0.0)
	assert_float(dmt).is_less_equal(dt_max + EPS)
	var ra: Array = frozen["replay"]
	var rb: Array = after["replay"]
	for i: int in [1, 2, 3]:
		assert_float(absf(float(rb[i]) - float(ra[i]))).override_failure_message(
				"replay clock %d jumped by more than dt_max" % i).is_less_equal(dt_max + EPS)
	assert_float(absf(float(after["punch_t"]) - float(frozen["punch_t"]))).is_less_equal(dt_max + EPS)
	var sa: Dictionary = frozen["sprites"]
	var sb: Dictionary = after["sprites"]
	for key: String in sa:
		if sa[key][0] == sb[key][0]:
			assert_int(absi(int(sb[key][1]) - int(sa[key][1]))).override_failure_message(
					"%s skipped frames after the Menu" % key).is_less_equal(1)
	return [frozen, after]


func _step_until(h: BattleModeHarness, cond: Callable, max_frames: int = 3000) -> void:
	var guard: int = 0
	while not bool(cond.call()) and guard < max_frames:
		h.step()
		guard += 1
	assert_bool(bool(cond.call())).override_failure_message("condition never reached").is_true()


## A squad Attack on the first enemy, queued as a beat on the live core.
func _queue_beat(h: BattleModeHarness) -> void:
	h.mode.settle_replay()
	h.emit_hit(h.mode.battle.squad[0], h.mode.battle.enemies[0], 1)


# --- Tests -------------------------------------------------------------------

func test_menu_mid_windup_freezes_every_clock_and_resumes_one_step() -> void:
	var h := _make(false)
	_queue_beat(h)
	_step_until(h, func() -> bool: return h.mode.replay.get_current_plan() != null)
	h.step(2)
	assert_float(h.mode.replay.get_windup_progress()).is_greater(0.0)
	assert_float(h.mode.replay.get_post_impact_time()).is_equal(0.0)
	var probes: Array[Dictionary] = await _freeze_and_release(h)
	assert_int(probes.size()).is_equal(2)


func test_menu_on_third_punch_frame_freezes_the_punch_and_resumes_one_step() -> void:
	var h := _make(false)
	_queue_beat(h)
	_step_until(h, func() -> bool: return not h.frames_of("beat_impact").is_empty())
	h.step(2)  # the impact frame shows t = 0; this is the punch's third frame
	assert_bool(_punch(h).is_running()).is_true()
	assert_float(_punch(h).elapsed()).is_equal_approx(3.0 * DT, EPS)
	var shown: Vector2i = h.stage.punch_offset_px()
	var probes: Array[Dictionary] = await _freeze_and_release(h)
	assert_int(probes.size()).is_equal(2)
	assert_that(probes[0]["punch_px"]).is_equal(shown)


func test_menu_mid_takeover_blend_freezes_the_blend_and_resumes_one_step() -> void:
	var h := _make(true)
	var cfg: PresentationConfig = h.mode.presentation_config
	_step_until(h, func() -> bool: return h.mode.replay.get_hold_time() >= cfg.blend_boss * 0.5)
	assert_bool(h.stage.is_blending()).is_true()
	var probes: Array[Dictionary] = await _freeze_and_release(h)
	assert_int(probes.size()).is_equal(2)
	var dp: float = float(probes[1]["blend_p"]) - float(probes[0]["blend_p"])
	assert_float(dp).is_greater_equal(0.0)
	# smoothstep's steepest slope is 1.5.
	assert_float(dp).is_less_equal(1.5 * cfg.follow_camera_dt_max / cfg.blend_boss + EPS)


func test_menu_only_pauses_ambience_not_other_overlays() -> void:
	var h := _make(false)
	h.machine.overlay_opened.emit(GameStateMachine.OverlayKind.DIALOGUE)
	h.machine.overlay_opened.emit(GameStateMachine.OverlayKind.DEFEAT_PROMPT)
	assert_bool(h.stage.is_ambient_paused()).is_false()


func test_no_shipped_mode_scene_node_always_processes() -> void:
	for path: String in _MODE_SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(text.contains("process_mode = %d" % Node.PROCESS_MODE_ALWAYS)).override_failure_message(
				"%s has a node set to always process (it would run under the Menu)" % path).is_false()
