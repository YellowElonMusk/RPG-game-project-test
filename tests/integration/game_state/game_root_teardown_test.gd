## GameRoot builds GameStateMachine and ModeHostSceneLoader as RefCounted
## objects that reference each other (constructor argument, `set_machine()`,
## and the loader's closures seeing the machine through a box). Godot never
## frees a RefCounted cycle, so they -- and the InputResolver the machine
## holds -- leaked at every exit. Freeing GameRoot must free them.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"


func test_freeing_game_root_frees_machine_loader_and_resolver() -> void:
	# Arrange: the real main scene, booted on the shipped data.
	var game_root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	game_root.data_root_override = "res://data"
	add_child(game_root)
	var machine_ref: WeakRef = weakref(game_root.machine)
	var loader_ref: WeakRef = weakref(game_root._loader)
	var resolver_ref: WeakRef = weakref(game_root.resolver)
	# A bool, not assert_object(): gdUnit keeps the asserted object alive.
	assert_bool(machine_ref.get_ref() != null).is_true()

	# Act
	remove_child(game_root)
	game_root.free()
	await get_tree().process_frame

	# Assert
	assert_bool(machine_ref.get_ref() == null).override_failure_message("GameStateMachine leaked").is_true()
	assert_bool(loader_ref.get_ref() == null).override_failure_message("ModeHostSceneLoader leaked").is_true()
	assert_bool(resolver_ref.get_ref() == null).override_failure_message("InputResolver leaked").is_true()
