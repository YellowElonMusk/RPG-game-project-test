## Boot's pipeline warm-up stage (ADR-0005 §11; story sprite-camera-presentation
## 069, AC-64). Behind an opaque Boot cover, in the MAIN viewport (pipelines are
## keyed by framebuffer format and MSAA, so a differently configured
## `SubViewport` would warm the wrong ones), it stages the real mode scenes
## the game plays -- every Overworld map, and every faction's ordinary and
## boss fight on every battle stage -- and draws each under every shipped
## lighting profile for `frames_per_state` frames. Battles also play their
## reveal, takeover and one squad Attack at speed, and light the Defeat
## spotlight, so those first draws happen here and not in play.
##
## Measured by `tools/capture/pipeline_compile_benchmark.gd`: with this stage,
## the scripted state cycle leaves every `Performance.PIPELINE_COMPILATIONS_*`
## counter unchanged. Not thread-safe; main thread only. Never runs headless
## (no rendering device) -- see `wanted()`.
##
## Usage example:
## [codeblock]
## if PipelineWarmup.wanted(DisplayServer.get_name(), catalog.state, OS.get_cmdline_user_args()):
##     var warmup := PipelineWarmup.new()
##     add_child(warmup)
##     warmup.finished.connect(_on_warmup_finished)
##     warmup.run(catalog)
## [/codeblock]
class_name PipelineWarmup
extends Node

## Emitted once every stage has been drawn and freed.
signal finished

const KIND_OVERWORLD: String = "overworld"
const KIND_BATTLE: String = "battle"
const PROFILES_DIR: String = "res://data/presentation/profiles"
const OVERWORLD_SCENE: String = "res://src/overworld/overworld_mode.tscn"
const BATTLE_SCENE: String = "res://src/battle/battle_mode.tscn"
## Debug builds only: skips the stage (the benchmark's no-warm-up comparison).
const SKIP_FLAG: String = "--skip-pipeline-warmup"
## Above every game layer: the Boot screen the warm-up draws behind.
const COVER_LAYER: int = 128
## Ordinary-fight size cap (enemies of one faction).
const MAX_ORDINARY_ENEMIES: int = 3
## A replay played at speed gives up after this many frames.
const REPLAY_FRAME_CAP: int = 600
## Mode-time seconds per rendered frame while a warm-up replay plays.
const REPLAY_STEP_S: float = 0.1

## Frames each (stage, profile) state is drawn (ADR-0005 §11: at least 2).
@export var frames_per_state: int = 2

## After `run()`: stages warmed, frames drawn, seconds taken.
var report: Dictionary = {}

var _done: bool = false
var _cover: CanvasLayer = null

## Every material, shader and environment the warm-up stages drew, kept
## alive for the session by whoever owns Boot (`GameRoot`). A pipeline lives
## only as long as its shader: when the last material using a shader is
## freed (a `ShaderMaterial`'s `Shader`, or a `BaseMaterial3D` feature set's
## generated shader), the engine drops its pipelines and play compiles them
## again (measured 2026-10-31: the warm-up alone, without this, still left
## 12 surface pipelines to compile in play).
var retained: Array[Resource] = []
var _retained_ids: Dictionary = {}


## True once `run()` has finished (and `finished` was emitted).
func is_done() -> bool:
	return _done


## Whether Boot should run the warm-up: a rendering display, a READY catalog
## (a FAILED one goes to Content Error, which draws no 3D), and -- debug
## builds only -- no `SKIP_FLAG`.
static func wanted(display_name: String, catalog_state: int,
		args: PackedStringArray = PackedStringArray()) -> bool:
	if display_name == "headless":
		return false
	if catalog_state != ContentCatalogService.State.READY:
		return false
	return not (OS.is_debug_build() and args.has(SKIP_FLAG))


## Every shipped lighting profile id, sorted.
static func profile_ids(dir: String = PROFILES_DIR) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	# An export lists converted resources as `<id>.tres.remap`.
	for f: String in DirAccess.get_files_at(dir):
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres") and not ids.has(name.get_basename()):
			ids.append(name.get_basename())
	ids.sort()
	return ids


## The stages to draw, from `catalog`: one `{kind: overworld, map_id}` per map
## record, then per battle stage id used by an encounter and per faction:
## an ordinary fight (up to `MAX_ORDINARY_ENEMIES` of its non-boss enemies)
## and, when the faction has a boss, a boss fight (the boss plus one ordinary
## enemy). Battle entries carry `{kind: battle, descriptor}`. Sorted by id.
static func build_plan(catalog: ContentCatalogService) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var map_ids: PackedStringArray = PackedStringArray()
	for rec: Resource in catalog.all_records(&"map"):
		map_ids.append((rec as MapData).id)
	map_ids.sort()
	for id: String in map_ids:
		plan.append({"kind": KIND_OVERWORLD, "map_id": id})

	var stage_ids: PackedStringArray = PackedStringArray()
	for rec: Resource in catalog.all_records(&"encounter"):
		var sid: String = (rec as EncounterData).battle_stage_id
		if not stage_ids.has(sid):
			stage_ids.append(sid)
	stage_ids.sort()
	var ordinary: Dictionary = {}  # faction id -> PackedStringArray
	var bosses: Dictionary = {}  # faction id -> boss enemy id
	var enemy_ids: PackedStringArray = PackedStringArray()
	for rec: Resource in catalog.all_records(&"enemy"):
		enemy_ids.append((rec as EnemyData).id)
	enemy_ids.sort()
	for id: String in enemy_ids:
		var e: EnemyData = catalog.get_record(&"enemy", id) as EnemyData
		if e.faction_id.is_empty():
			continue
		if e.is_boss:
			if not bosses.has(e.faction_id):
				bosses[e.faction_id] = e.id
		else:
			# Packed arrays are values: append to a copy, store it back.
			var list: PackedStringArray = ordinary.get(e.faction_id, PackedStringArray())
			list.append(e.id)
			ordinary[e.faction_id] = list
	var factions: PackedStringArray = PackedStringArray()
	for rec: Resource in catalog.all_records(&"faction"):
		factions.append((rec as FactionData).id)
	factions.sort()
	for sid: String in stage_ids:
		for fid: String in factions:
			var foes: PackedStringArray = ordinary.get(fid, PackedStringArray())
			if not foes.is_empty():
				plan.append({"kind": KIND_BATTLE, "descriptor": _descriptor(
						"warmup_%s_%s" % [fid, sid], foes.slice(0, MAX_ORDINARY_ENEMIES), sid, fid, false)})
			if bosses.has(fid):
				var boss_party: PackedStringArray = PackedStringArray([String(bosses[fid])])
				if not foes.is_empty():
					boss_party.append(foes[0])
				plan.append({"kind": KIND_BATTLE, "descriptor": _descriptor(
						"warmup_boss_%s_%s" % [fid, sid], boss_party, sid, fid, true)})
	return plan


static func _descriptor(id: String, enemies: PackedStringArray, stage_id: String,
		faction_id: String, is_boss: bool) -> EncounterDescriptor:
	var d := EncounterDescriptor.new()
	d.encounter_id = id
	d.enemy_ids = enemies
	d.battle_stage_id = stage_id
	d.faction_id = faction_id
	d.is_boss = is_boss
	return d


## Draws every planned stage behind the Boot cover, then frees it all and
## emits `finished`. A coroutine: callers either await it or connect
## `finished`.
func run(catalog: ContentCatalogService) -> void:
	var t0: int = Time.get_ticks_usec()
	var c0: Dictionary = _counters()
	_cover = CanvasLayer.new()
	_cover.name = "BootCover"
	_cover.layer = COVER_LAYER
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(rect)
	add_child(_cover)
	var profiles: Array[LightingProfile] = []
	for id: String in profile_ids():
		var p: LightingProfile = load(PROFILES_DIR.path_join(id + ".tres")) as LightingProfile
		if p != null:
			profiles.append(p)
	var frames: int = 0
	var stages: PackedStringArray = PackedStringArray()
	var squad: Array[Combatant] = ChapterFlow.build_squad(catalog)
	for entry: Dictionary in build_plan(catalog):
		if String(entry["kind"]) == KIND_OVERWORLD:
			frames += await _warm_overworld(String(entry["map_id"]), catalog, squad, profiles)
			stages.append("overworld:%s" % entry["map_id"])
		else:
			var d: EncounterDescriptor = entry["descriptor"]
			frames += await _warm_battle(d, squad, profiles)
			stages.append("battle:%s" % d.encounter_id)
	_cover.queue_free()
	_cover = null
	await get_tree().process_frame
	report = {
		"stages": stages,
		"profiles": profiles.size(),
		"frames": frames,
		"seconds": float(Time.get_ticks_usec() - t0) / 1000000.0,
		"counters_delta": _delta(c0, _counters()),
	}
	_done = true
	finished.emit()


func _warm_overworld(map_id: String, catalog: ContentCatalogService, squad: Array[Combatant],
		profiles: Array[LightingProfile]) -> int:
	var mode: OverworldMode = (load(OVERWORLD_SCENE) as PackedScene).instantiate() as OverworldMode
	mode.world_state = WorldState.new()
	mode.encounter_catalog = catalog
	mode.party_source = func() -> Array[Combatant]:
		return squad
	mode.setup(null, MapEntryPayload.new(map_id, &""))
	add_child(mode)
	var n: int = await _warm_profiles(mode, profiles)
	_retain(mode)
	mode.queue_free()
	await get_tree().process_frame
	return n + 1


func _warm_battle(d: EncounterDescriptor, squad: Array[Combatant], profiles: Array[LightingProfile]) -> int:
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party.assign(squad)
	var mode: BattleMode = (load(BATTLE_SCENE) as PackedScene).instantiate() as BattleMode
	mode.setup(null, payload)
	add_child(mode)
	var n: int = 0
	var stage: DioramaStage = _find_stage(mode)
	if stage != null:
		stage.bind_profiles(_resolver(profiles))
	_make_camera_current(mode)
	if mode.battle != null:
		# The reveal (and a boss's takeover), then one squad Attack, at speed.
		mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
		n += await _play_replay(mode)
		for i: int in 2:
			mode.handle_action(InputActions.CONFIRM, true)
			mode.handle_action(InputActions.CONFIRM, false)
		n += await _play_replay(mode)
	n += await _warm_profiles(mode, profiles)
	# The Defeat spotlight (story 053), lit.
	if stage != null:
		var spot := DefeatSpotlight.new()
		stage.add_child(spot)
		spot.setup(mode.presentation_config)
		spot.aim_at(Vector3.ZERO)
		spot.set_progress(1.0)
		n += await _frames(frames_per_state)
	_retain(mode)
	mode.queue_free()
	await get_tree().process_frame
	return n + 1


func _play_replay(mode: BattleMode) -> int:
	var n: int = 0
	while n < REPLAY_FRAME_CAP:
		mode.step_replay(REPLAY_STEP_S)
		await get_tree().process_frame
		n += 1
		if not mode.is_presenting() and (mode.battle == null
				or mode.battle.state != BattleCore.State.ENEMY_TURN):
			break
	return n


## Draws `mode`'s stage under every profile, `frames_per_state` frames each.
func _warm_profiles(mode: Node, profiles: Array[LightingProfile]) -> int:
	await get_tree().process_frame
	_make_camera_current(mode)
	var stage: DioramaStage = _find_stage(mode)
	var n: int = 0
	if stage == null:
		return await _frames(frames_per_state)
	for p: LightingProfile in profiles:
		stage.apply_profile(p, 0.0)
		n += await _frames(frames_per_state)
	return n


## Adds every material / shader / environment under `n` to `retained`.
func _retain(n: Node) -> void:
	if n is GeometryInstance3D:
		var g: GeometryInstance3D = n as GeometryInstance3D
		_keep(g.material_override)
		_keep(g.material_overlay)
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			for i: int in mi.mesh.get_surface_count():
				_keep(mi.get_surface_override_material(i))
				_keep(mi.mesh.surface_get_material(i))
	if n is GPUParticles3D:
		var p: GPUParticles3D = n as GPUParticles3D
		_keep(p.process_material)
		for i: int in p.draw_passes:
			var m: Mesh = p.get_draw_pass_mesh(i)
			if m != null:
				for s: int in m.get_surface_count():
					_keep(m.surface_get_material(s))
	if n is CanvasItem:
		_keep((n as CanvasItem).material)
	if n is WorldEnvironment:
		_keep((n as WorldEnvironment).environment)
	for c: Node in n.get_children():
		_retain(c)


func _keep(r: Resource) -> void:
	if r == null or _retained_ids.has(r.get_instance_id()):
		return
	_retained_ids[r.get_instance_id()] = true
	retained.append(r)
	if r is ShaderMaterial and (r as ShaderMaterial).shader != null:
		_keep((r as ShaderMaterial).shader)
	if r is Material and (r as Material).next_pass != null:
		_keep((r as Material).next_pass)


func _frames(count: int) -> int:
	for i: int in count:
		await get_tree().process_frame
	return count


func _resolver(profiles: Array[LightingProfile]) -> Callable:
	var by_id: Dictionary = {}
	for p: LightingProfile in profiles:
		by_id[StringName(p.resource_path.get_file().get_basename())] = p
	return func(id: StringName) -> LightingProfile:
		return by_id.get(id) as LightingProfile


static func _find_stage(n: Node) -> DioramaStage:
	if n is DioramaStage:
		return n as DioramaStage
	for c: Node in n.get_children():
		var s: DioramaStage = _find_stage(c)
		if s != null:
			return s
	return null


static func _make_camera_current(n: Node) -> void:
	if n is Camera3D:
		(n as Camera3D).make_current()
		return
	for c: Node in n.get_children():
		_make_camera_current(c)


static func _counters() -> Dictionary:
	return {
		"canvas": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		"mesh": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		"surface": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		"draw": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		"specialization": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
	}


static func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in a:
		out[k] = int(b[k]) - int(a[k])
	return out
