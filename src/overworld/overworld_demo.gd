## Debug-only entry point for the walkable placeholder Town (story 136).
## Launch: `godot --path . res://src/overworld/overworld_demo.tscn`, or open
## the scene and press F6. `run/main_scene` (GameRoot -> ChapterMode) is
## untouched; this scene is a second door, refused in a release build.
##
## Builds the same collaborators as `GameRoot._ready()`, in the same order
## (content boot, `InputResolver`/`InputSystem`, `ModeHostSceneLoader` with
## the `pre_setup` injector, `GameStateMachine`), plus the
## `PresentationDirector` GameRoot does not wire yet. The only difference is
## a copy of `TransitionConfig` whose OVERWORLD row points at
## `overworld_mode.tscn` instead of `ChapterMode`, and an automatic
## Title -> Overworld request once Title is up. So the mode arrives through
## the real loader, `setup()` comes from `pre_setup`, and the `overworld`
## profile is applied by the director on `mode_entered`.
class_name OverworldDemo
extends Node

const _TRANSITION_CONFIG_PATH: String = "res://data/config/transition_config.tres"
const _INPUT_CONFIG_PATH: String = "res://data/config/input_config.tres"
const _BINDINGS_RECORD_ID: String = "bindings_default"
const _OVERWORLD_SCENE_PATH: String = "res://src/overworld/overworld_mode.tscn"
const _DATA_ROOT: String = "res://data"

var _machine: GameStateMachine = null
var _loader: ModeHostSceneLoader = null
var _resolver: InputResolver = null

@onready var _mode_host: Node = %ModeHost
@onready var _overlay_host: CanvasLayer = %OverlayHost
@onready var _transition_layer: CanvasLayer = %TransitionLayer
@onready var _services: Node = %Services


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	if OS.is_debug_build():
		ContentBootstrap.run(catalog(), _DATA_ROOT)


func _ready() -> void:
	if not OS.is_debug_build():
		push_error("OverworldDemo: debug builds only")
		get_tree().quit()
		return
	var game_log := GameStateLog.new()
	var config: TransitionConfig = _demo_transition_config()
	_resolver = _build_input_resolver()
	var input_system := InputSystem.new()
	_services.add_child(input_system)
	input_system.setup(_resolver)

	var presenter := InterimFadePresenter.new(_transition_layer)
	var machine_box: Array = [null]
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		mode.setup(machine_box[0], payload)
	var result_getter := func() -> int:
		return (machine_box[0] as GameStateMachine).last_battle_result
	_loader = ModeHostSceneLoader.new(
			_mode_host, config, game_log, pre_setup, result_getter, _overlay_host, Callable())
	var machine := GameStateMachine.new(
			_loader, presenter, config, catalog(), get_tree().quit, game_log, null, Callable())
	machine_box[0] = machine
	_machine = machine
	_loader.set_machine(machine)
	machine.mode_entered.connect(_loader.on_mode_entered)
	machine.bind_action_source(_resolver)

	var director := PresentationDirector.new()
	_services.add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())

	machine.transition_finished.connect(_on_transition_finished)
	machine.tick(0.0)


func _process(delta: float) -> void:
	if _machine != null:
		_machine.tick(delta)


## The live mode node under `ModeHost` (the `OverworldMode` once entered).
func current_mode_node() -> Node:
	return null if _loader == null else _loader.current_mode_node()


## The machine driving this demo (null before `_ready()`).
func get_machine() -> GameStateMachine:
	return _machine


## The `ContentCatalog` autoload, read through the tree (the identifier does
## not compile under `-s` scripts).
func catalog() -> ContentCatalogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"ContentCatalog") as ContentCatalogService


func _on_transition_finished(to: GameStateMachine.Mode) -> void:
	if to == GameStateMachine.Mode.TITLE:
		_machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)


func _demo_transition_config() -> TransitionConfig:
	var source: TransitionConfig = ResourceLoader.load(_TRANSITION_CONFIG_PATH) as TransitionConfig
	if source == null:
		push_error("OverworldDemo: %s missing; using defaults" % _TRANSITION_CONFIG_PATH)
		source = TransitionConfig.new()
	var config: TransitionConfig = source.duplicate() as TransitionConfig
	var paths: Dictionary = config.mode_scene_paths.duplicate()
	paths[GameStateMachine.Mode.OVERWORLD] = _OVERWORLD_SCENE_PATH
	config.mode_scene_paths = paths
	return config


func _build_input_resolver() -> InputResolver:
	var input_config: InputConfig = ResourceLoader.load(_INPUT_CONFIG_PATH) as InputConfig
	if input_config == null:
		input_config = InputConfig.new()
	var bindings: InputBindings = null
	if catalog().state != ContentCatalogService.State.FAILED:
		bindings = catalog().get_record(&"bindings", _BINDINGS_RECORD_ID) as InputBindings
	if bindings == null:
		bindings = InputResolver.make_fallback_bindings()
	return InputResolver.new(bindings, input_config)
