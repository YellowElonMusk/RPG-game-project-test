## Story 041, AC-37 [I] (GDD rule 11; ADR-0005 §6): on a boss stage, at
## least one node tagged as the fight's faction shape exists, and its bounds
## lie inside the battle camera's view on every frame of the takeover blend
## and hold. The battle camera never moves, rotates, zooms or changes FOV in
## a fight, and the hit-punch is dropped for the whole takeover (story 013),
## so "every frame" is one static check per supported window shape, against
## `BattleFraming.camera_state()` (`Projection.create_frustum_aspect`, never
## `Camera3D.get_camera_projection()`).
##
## These cases run the check on the real battle scene's `DioramaStage` with
## fixture shapes. Whether the shipped boss stage passes for every boss
## faction depends on authored faction-shape art (out of scope here; see the
## story's evidence note).
extends GdUnitTestSuite

const _BATTLE_SCENE := "res://src/battle/battle_mode.tscn"
const _BOSS_STAGE := "res://data/presentation/stages/battle_boss.tres"
const _FACTION := "faction_fixture_a"
const _OTHER_FACTION := "faction_fixture_b"
## A fixture sign's size (m) and a depth behind the back row (m).
const _SIGN := Vector3(1.0, 1.0, 0.1)
const _SIGN_Z: float = 14.0


func _stage_node() -> DioramaStage:
	var mode: Node = auto_free((load(_BATTLE_SCENE) as PackedScene).instantiate())
	return mode.get_node(^"%DioramaStage") as DioramaStage


## The shipped boss stage with `shapes` (faction id -> sign centre) declared.
func _boss_stage(shapes: Dictionary) -> BattleStage:
	var stage := (load(_BOSS_STAGE) as BattleStage).duplicate() as BattleStage
	var scenes: Dictionary[String, PackedScene] = {}
	for faction: String in shapes:
		scenes[faction] = _sign_scene(shapes[faction])
	stage.faction_shapes = scenes
	return stage


## A packed sign: a root `Node3D` with a box mesh child centred at `centre`.
func _sign_scene(centre: Vector3) -> PackedScene:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = _SIGN
	mesh.mesh = box
	mesh.position = centre
	root.add_child(mesh)
	mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_shape_inside_view_passes_at_every_window_shape() -> void:
	var node := _stage_node()
	var stage := _boss_stage({_FACTION: Vector3(-3.0, 2.5, -_SIGN_Z)})
	var placed: Node3D = node.place_faction_shape(stage, _FACTION)
	assert_object(placed).is_not_null()
	assert_str(String(placed.get_meta(&"capture_id", ""))).is_equal(String(DioramaStage.FACTION_SHAPE_TAG))
	assert_str(String(placed.get_meta(DioramaStage.META_FACTION_ID, ""))).is_equal(_FACTION)
	assert_int(node.faction_shape_bounds(_FACTION).size()).is_equal(1)
	assert_array(Array(node.faction_shape_errors(stage, PresentationConfig.new(), _FACTION))).is_empty()


func test_no_shape_for_the_faction_fails() -> void:
	var node := _stage_node()
	var stage := _boss_stage({})
	assert_object(node.place_faction_shape(stage, _FACTION)).is_null()
	var errors := node.faction_shape_errors(stage, PresentationConfig.new(), _FACTION)
	assert_int(errors.size()).is_greater(0)
	assert_bool("\n".join(errors).contains(_FACTION)).is_true()


func test_other_factions_shape_does_not_count() -> void:
	var node := _stage_node()
	var stage := _boss_stage({_OTHER_FACTION: Vector3(-3.0, 2.5, -_SIGN_Z)})
	node.place_faction_shape(stage, _OTHER_FACTION)
	assert_int(node.faction_shape_bounds(_FACTION).size()).is_equal(0)
	assert_int(node.faction_shape_errors(stage, PresentationConfig.new(), _FACTION).size()).is_greater(0)


func test_shape_outside_view_fails() -> void:
	var node := _stage_node()
	var stage := _boss_stage({_FACTION: Vector3(-20.0, 2.5, -_SIGN_Z)})
	node.place_faction_shape(stage, _FACTION)
	assert_int(node.faction_shape_errors(stage, PresentationConfig.new(), _FACTION).size()).is_greater(0)


func test_shape_cut_by_the_16_9_edge_fails_though_inside_at_21_9() -> void:
	var config := PresentationConfig.new()
	var stage := _boss_stage({_FACTION: Vector3(-4.6, 2.5, -_SIGN_Z)})
	var box := AABB(Vector3(-4.6, 2.5, -_SIGN_Z) - _SIGN * 0.5, _SIGN)
	assert_bool(SpriteProjection.box_in_view(box,
			BattleFraming.camera_state(stage, config, Vector2i(2520, 1080)), Vector2i(2520, 1080))).is_true()
	assert_bool(SpriteProjection.box_in_view(box,
			BattleFraming.camera_state(stage, config, Vector2i(1920, 1080)), Vector2i(1920, 1080))).is_false()
	var node := _stage_node()
	node.place_faction_shape(stage, _FACTION)
	var errors := node.faction_shape_errors(stage, config, _FACTION)
	assert_bool("\n".join(errors).contains("1920x1080")).is_true()
	assert_bool("\n".join(errors).contains("2520x1080")).is_false()


func test_shape_behind_the_camera_is_never_in_view() -> void:
	var stage := _boss_stage({})
	var box := AABB(Vector3(-0.5, 1.0, 2.0), _SIGN)
	for vp: Vector2i in BattleFraming.SUPPORTED_VIEWPORTS:
		assert_bool(SpriteProjection.box_in_view(box,
				BattleFraming.camera_state(stage, PresentationConfig.new(), vp), vp)).is_false()


func test_non_boss_stage_needs_no_shape() -> void:
	var node := _stage_node()
	var stage := _boss_stage({})
	stage.is_boss = false
	assert_array(Array(node.faction_shape_errors(stage, PresentationConfig.new(), _FACTION))).is_empty()
