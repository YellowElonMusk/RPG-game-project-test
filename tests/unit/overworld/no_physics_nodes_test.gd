## Story 079, AC-30e (ADR-0012, no physics engine): shipped maps contain no
## collision object, soft body, ray or shape cast, spring arm, joint,
## physical-bone simulator or CSG node; every GridMap has collision layer
## and mask 0 and no item shapes; every TileMapLayer has collision off.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_the_shipped_maps_have_no_physics() -> void:
	for name: String in _MAPS:
		var map: OverworldMap = auto_free((load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
		assert_array(Array(MapValidator.check_no_physics(name, map))).is_empty()


func test_each_banned_node_class_is_reported(node_class: String, cls: String, test_parameters := [
		["StaticBody3D", "CollisionObject3D"],
		["Area3D", "CollisionObject3D"],
		["CharacterBody2D", "CollisionObject2D"],
		["SoftBody3D", "SoftBody3D"],
		["RayCast3D", "RayCast3D"],
		["ShapeCast3D", "ShapeCast3D"],
		["RayCast2D", "RayCast2D"],
		["ShapeCast2D", "ShapeCast2D"],
		["SpringArm3D", "SpringArm3D"],
		["HingeJoint3D", "Joint3D"],
		["PinJoint2D", "Joint2D"],
		["PhysicalBoneSimulator3D", "PhysicalBoneSimulator3D"],
		["CSGBox3D", "CSGShape3D"],
	]) -> void:
	var node: Node = ClassDB.instantiate(node_class)
	var root: Node3D = auto_free(Node3D.new())
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(node)
	var errors: PackedStringArray = MapValidator.check_no_physics("map_fixture", root)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("is a %s" % cls)


func test_a_colliding_tile_layer_and_grid_map_are_reported() -> void:
	var root: Node3D = auto_free(Node3D.new())
	var layer := TileMapLayer.new()
	root.add_child(layer)
	assert_str("\n".join(MapValidator.check_no_physics("map_fixture", root))).contains("collision_enabled on")
	layer.collision_enabled = false
	var grid := GridMap.new()
	root.add_child(grid)
	assert_str("\n".join(MapValidator.check_no_physics("map_fixture", root))).contains("collision_layer/mask set")
	grid.collision_layer = 0
	grid.collision_mask = 0
	var lib := MeshLibrary.new()
	lib.create_item(0)
	lib.set_item_shapes(0, [BoxShape3D.new(), Transform3D.IDENTITY])
	grid.mesh_library = lib
	assert_str("\n".join(MapValidator.check_no_physics("map_fixture", root))).contains("item 0 has collision shapes")
	lib.set_item_shapes(0, [])
	assert_array(Array(MapValidator.check_no_physics("map_fixture", root))).is_empty()
