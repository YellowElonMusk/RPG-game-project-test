## The persistent main scene (ADR-0002 §2, §9; ADR-0004 §2; this story's own
## Control Manifest rule). `_enter_tree()` runs only `ContentBootstrap.run()`
## -- everything else is built in `_ready()`, in the Implementation Notes'
## pinned order: `TransitionConfig`, `InputConfig`, `InputResolver`,
## `InputSystem` (a child of `Services`), `GameStateMachine` and its
## collaborators, then `bind_action_source()`. Mode swaps are child swaps
## under `ModeHost`; there is no `SceneTree.change_scene_*`, no
## tree-wide pause, and Game State is never an autoload -- every consumer
## reaches the machine through `setup()` or, for tests and the demo scene,
## through this node's own `machine` getter.
##
## Usage example:
## [codeblock]
## # res://project.godot: run/main_scene = "res://src/game_state/game_root.tscn"
## # A test, before add_child():
## var root: GameRoot = preload("res://src/game_state/game_root.tscn").instantiate()
## root.data_root_override = "res://tests/unit/content_data/fixtures/valid_one_of_each"
## add_child(root)
## [/codeblock]
class_name GameRoot
extends Node

const _TRANSITION_CONFIG_PATH: String = "res://data/config/transition_config.tres"
const _INPUT_CONFIG_PATH: String = "res://data/config/input_config.tres"
const _BINDINGS_RECORD_ID: String = "bindings_default"

## Test seam (QA fix, Implementation Notes): an integration test sets this
## before `add_child()` to boot against a fixture content root instead of
## resolving `--data-root=` / the default `res://data`. Empty in production.
var data_root_override: String = ""
## Tests point saves at their own folder (default `user://saves`).
var save_dir_override: String = ""

## Read-only: the one `GameStateMachine` for this session, handed to tests
## and the demo scene so neither needs a second way to reach it (Game State
## is never an autoload -- control manifest).
var machine: GameStateMachine:
	get:
		return _machine

## Test seam (Check 2): `true` once `_ready()` built the input resolver from
## `InputResolver.make_fallback_bindings()` (the catalog was `FAILED`)
## rather than the catalog's own `bindings_default` record.
var used_fallback_bindings: bool:
	get:
		return _used_fallback_bindings

## Read-only: the `InputResolver` bound to `machine` as its action source
## (Check 1) -- feeding an event through this exact instance is how a test
## proves the binding, with no new surface on `GameStateMachine` itself.
var resolver: InputResolver:
	get:
		return _resolver

## Read-only: the `WorldState` injected into the current `OverworldMode`
## (story 137); a fresh one per New Game.
var world_state: WorldState:
	get:
		return _world_state

var _world_state: WorldState = null
## Every camp's return (story 089), read from the map scenes at boot.
var _camp_directory: CampDirectory = null
## Save/Load (ADR-0009), under Services.
var _save_service: SaveService = null
var _squad: Array[Combatant] = []
var _machine: GameStateMachine = null
var _loader: ModeHostSceneLoader = null
## The box the loader's closures read the machine through (see `_ready()`);
## a member so `_release_machine()` can empty it.
var _machine_box: Array = [null]
var _resolver: InputResolver = null
var _used_fallback_bindings: bool = false

@onready var _mode_host: Node = %ModeHost
@onready var _overlay_host: CanvasLayer = %OverlayHost
@onready var _transition_layer: CanvasLayer = %TransitionLayer
@onready var _services: Node = %Services


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## One call, nothing else (review checklist, Check 6): boots the content
## catalog before any node in this scene queries it. `data_root_override`
## wins when set (tests); otherwise `resolve_data_root()` reads
## `--data-root=` off the real command line, defaulting to `res://data`.
func _enter_tree() -> void:
	var data_root: String = data_root_override if not data_root_override.is_empty() \
			else resolve_data_root(OS.get_cmdline_user_args())
	ContentBootstrap.run(catalog(), data_root)


## Builds every collaborator, in the Implementation Notes' pinned order, then
## ticks `GameStateMachine` once so a catalog that was already terminal by
## `_enter_tree()` (`ContentBootstrap.run()` is synchronous) starts its Boot
## transition the same frame rather than waiting one.
func _ready() -> void:
	var game_log := GameStateLog.new()
	# SettingsService: TODO(save-load) once ADR-0009 ships -- absent, skipped.
	var config: TransitionConfig = _load_transition_config(game_log)
	var input_config: InputConfig = _load_input_config()
	var resolver: InputResolver = _build_input_resolver(input_config)
	_resolver = resolver

	var input_system := InputSystem.new()
	_services.add_child(input_system)
	input_system.setup(resolver)

	# ADR-0009: Save/Load, built before the machine so the machine's
	# mark_unsaved hook can point at it; set up once the machine exists.
	_save_service = SaveService.new()
	_save_service.name = "SaveService"
	_services.add_child(_save_service)
	if _world_state == null:
		_world_state = WorldState.new()
	var presenter := InterimFadePresenter.new(_transition_layer)
	# machine_box: ModeHostSceneLoader is a constructor argument of
	# GameStateMachine, so it is built first and has no reference to the
	# machine yet -- the box lets pre_setup's closure see the real instance
	# once it exists (mode_host_scene_loader.gd's own documented pattern).
	# ADR-0005 §12: the one flash gate, on real time. Reduce Flashing reads a
	# fixed FlashSettings until the Settings service exists.
	var flash_gate := FlashGate.new()
	flash_gate.name = "FlashGate"
	_services.add_child(flash_gate)
	var flash_decls: Dictionary[StringName, FlashSourceDecl] = {}
	for decl: FlashSourceDecl in PresentationValidators.load_flash_sources():
		flash_decls[decl.source_id] = decl
	flash_gate.setup(Time.get_ticks_usec, PresentationConfig.new(), flash_decls, FlashSettings.new())
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		if mode is OverworldMode:
			_inject_overworld(mode as OverworldMode, payload)
			(mode as OverworldMode).camp_directory = _camp_directory
		elif mode is InterimCampMode:
			(mode as InterimCampMode).camp_directory = _camp_directory
			(mode as InterimCampMode).save_service = _save_service
		elif mode is TitleMode:
			(mode as TitleMode).save_service = _save_service
		elif mode is BattleMode:
			(mode as BattleMode).flash_gate = flash_gate
		mode.setup(_machine_box[0], payload)
	# The loader's result getter: the thawed Overworld's on_thawed() needs the
	# battle result, and the return swap carries no payload (story 014).
	var result_getter := func() -> int:
		return (_machine_box[0] as GameStateMachine).last_battle_result
	var loader := ModeHostSceneLoader.new(
			_mode_host, config, game_log, pre_setup, result_getter, _overlay_host, Callable())
	_loader = loader

	var machine := GameStateMachine.new(
			loader, presenter, config, catalog(), get_tree().quit, game_log,
			FlashGatePortAdapter.new(flash_gate), _save_service.mark_unsaved)
	_machine_box[0] = machine
	_machine = machine
	loader.set_machine(machine)
	machine.mode_entered.connect(loader.on_mode_entered)
	machine.bind_action_source(resolver)
	var save_config := SaveConfig.new()
	if not save_dir_override.is_empty():
		save_config.save_dir = save_dir_override
	_save_service.setup(machine, catalog(), SaveFileSystem.new(), save_config,
			SaveBootstrap.participants(machine, _world_state, _camp_return),
			func() -> int: return int(Time.get_unix_time_from_system()))
	loader.save_commit = _save_service.commit_if_loaded

	# Mode-entry lighting (sprite-camera story 008), as overworld_demo.gd.
	var director := PresentationDirector.new()
	_services.add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())

	# TODO(ui-framework): PresentationDirector / UiService once ADR-0008
	# ships -- pre_setup and the overlay pre_setup above stay no-op Callables
	# until then (ADR-0008 §8).
	# TODO(save-load): SaveService once ADR-0009 ships -- the loader's
	# payload_commit slot carries the battle-result getter until then.

	_validate_maps()
	machine.tick(0.0)


## Story 137 (AC-137a; ADR-0012 §4-5): the Overworld slot's injections --
## a fresh `WorldState`, the content catalog as the `enc_` record source and
## ChapterFlow's interim squad as the party source. The squad is built once
## per OverworldMode instance, so every battle gets the same `Combatant`s
## and HP/MP carry over (ADR-0002 §7). Story 138: a map change
## (`MapEntryPayload`) keeps the same `WorldState` and squad; any other entry
## (New Game) builds fresh ones.
func _inject_overworld(overworld: OverworldMode, payload: RefCounted = null) -> void:
	if _world_state == null:
		_world_state = WorldState.new()
	# New Game (no payload): the one WorldState back to defaults, a fresh
	# squad. A map change keeps both; a Continue (`LoadedSave`) keeps the
	# WorldState Save/Load just committed (ADR-0009 §6).
	if payload == null:
		_world_state.reset_to_new_game()
		_squad = ChapterFlow.build_squad(catalog())
		_apply_opening_step(overworld.config)
	elif _squad.is_empty():
		_squad = ChapterFlow.build_squad(catalog())
	var squad: Array[Combatant] = _squad
	overworld.world_state = _world_state
	overworld.encounter_catalog = catalog()
	overworld.party_source = func() -> Array[Combatant]:
		return squad


## Story 138 (ADR-0012 §3; story 080): the load-time map validator. Each
## problem is a `push_error`; a `FAILED` catalog is skipped.
func _validate_maps() -> void:
	if catalog().state == ContentCatalogService.State.FAILED:
		return
	for err: String in MapValidator.validate_catalog(catalog(), OverworldConfig.new()):
		push_error("MapValidator: " + err)
	_camp_directory = CampDirectory.from_catalog(catalog(), OverworldConfig.new())


func _process(delta: float) -> void:
	if _machine != null:
		_machine.tick(delta)
		# Playtime stops while the Menu is open (ADR-0009 §3).
		if _save_service != null and not (GameStateMachine.OverlayKind.MENU in _machine.overlay_stack):
			_save_service.add_playtime(delta)


## E8 (manifest advisory): a detached, frozen Overworld is never reparented
## onto a freed `GameRoot`, so it is freed explicitly here rather than left
## an orphan.
func _exit_tree() -> void:
	_free_frozen_overworld()
	_release_machine()


## The machine and its loader are RefCounted and hold each other (the loader
## is the machine's constructor argument; `set_machine()` and the loader's
## closures, through `_machine_box`, point back), and the machine holds the
## InputResolver. Godot never frees a RefCounted cycle, so it is broken here
## or all of them leak at exit.
func _release_machine() -> void:
	if _machine != null:
		_machine.bind_action_source(null)
	if _loader != null:
		_loader.set_machine(null)
	_machine_box[0] = null
	_machine = null
	_loader = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_free_frozen_overworld()


## The live `GameMode` node under `ModeHost`, or `null` -- the one seam tests
## and the demo scene need to reach a running mode (e.g. `BattleMode`, for
## `DebugLaunchArgs.force_outcome()`) without a second lookup path into the
## scene tree.
func current_mode_node() -> Node:
	if _loader == null:
		return null
	return _loader.current_mode_node()


## The top overlay's node, or null (tests drive an open Dialogue line).
func current_overlay_node() -> Node:
	if _loader == null:
		return null
	return _loader.current_overlay_node()


## `--data-root=<path>` overrides the default `res://data` (QA fix, Check 5).
## Pure: reads only the given `args`, never `OS` directly, so a test can call
## it with a literal array.
static func resolve_data_root(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--data-root="):
			return arg.trim_prefix("--data-root=")
	return "res://data"


func _load_transition_config(game_log: GameStateLog) -> TransitionConfig:
	var config: TransitionConfig = ResourceLoader.load(_TRANSITION_CONFIG_PATH) as TransitionConfig
	if config == null:
		push_error("GameRoot: %s is missing or not a TransitionConfig; using an empty default." \
				% _TRANSITION_CONFIG_PATH)
		return TransitionConfig.new()
	if not config.validate(game_log):
		push_error("GameRoot: %s failed validate() -- see the GameStateLog error(s) above." \
				% _TRANSITION_CONFIG_PATH)
	return config


func _load_input_config() -> InputConfig:
	var config: InputConfig = ResourceLoader.load(_INPUT_CONFIG_PATH) as InputConfig
	if config == null:
		push_error("GameRoot: %s is missing or not an InputConfig; using defaults." % _INPUT_CONFIG_PATH)
		return InputConfig.new()
	return config


## Fallback bindings (a code constant) only when the catalog is `FAILED`
## (ADR-0003 §7, control manifest Required rule) -- never a second
## default-bindings source otherwise.
func _build_input_resolver(input_config: InputConfig) -> InputResolver:
	var bindings: InputBindings
	if catalog().state == ContentCatalogService.State.FAILED:
		bindings = InputResolver.make_fallback_bindings()
		_used_fallback_bindings = true
	else:
		bindings = catalog().get_record(&"bindings", _BINDINGS_RECORD_ID) as InputBindings
	return InputResolver.new(bindings, input_config)


func _free_frozen_overworld() -> void:
	if _loader != null:
		_loader.free_frozen_overworld()


## The `ContentCatalog` autoload, fetched by node path rather than by its
## global identifier: under a `-s` main-loop script (the Content Error test
## harness, CI tools) autoload identifiers are not in scope when scripts
## compile, so the identifier is a compile error there. Read through the
## main loop so it also works before this node is in the tree.
func catalog() -> ContentCatalogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"ContentCatalog") as ContentCatalogService


## Where a save made in Camp continues: the camp's return EntryPoint
## (`CampDirectory`), bound into the overworld save participant.
func _camp_return(camp_id: String) -> MapEntryPayload:
	return _camp_directory.return_payload(camp_id) if _camp_directory != null else null


## The Save/Load service (ADR-0009), for tests and the Menu.
func save_service() -> SaveService:
	return _save_service


## Story 057 (GDD rule 8): a New Game applies the chapter's opening step
## flags (Paris: `permits_mandatory`) to the fresh WorldState before the
## Overworld loads its first map or accepts any input.
func _apply_opening_step(cfg: OverworldConfig) -> void:
	if not ResourceLoader.exists(cfg.chapter_steps_path):
		push_error("GameRoot: no chapter steps at %s" % cfg.chapter_steps_path)
		return
	var steps: ChapterSteps = ResourceLoader.load(cfg.chapter_steps_path) as ChapterSteps
	if steps == null or steps.steps.is_empty():
		return
	_world_state.chapter_step = steps.steps[0].id
	for flag: String in steps.steps[0].flags_on_enter:
		_world_state.set_flag(flag)
