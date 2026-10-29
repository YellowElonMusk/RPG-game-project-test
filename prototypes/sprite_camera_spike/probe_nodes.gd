# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree

# Throwaway probe: confirm property names before building the spike scene.

func _initialize() -> void:
	print("=== Camera3D props (compositor?) ===")
	for p in ClassDB.class_get_property_list("Camera3D", true):
		if "compositor" in p.name or "frustum" in p.name or "keep_aspect" in p.name or "fov" in p.name or "projection" in p.name.to_lower():
			print("  ", p.name)
	print("=== WorldEnvironment props ===")
	for p in ClassDB.class_get_property_list("WorldEnvironment", true):
		if "compositor" in p.name:
			print("  ", p.name)
	print("=== AnimatedSprite3D props ===")
	for p in ClassDB.class_get_property_list("AnimatedSprite3D", true):
		print("  ", p.name)
	print("=== GeometryInstance3D props (cull mask etc) ===")
	for p in ClassDB.class_get_property_list("GeometryInstance3D", true):
		print("  ", p.name)
	print("=== Light3D props ===")
	for p in ClassDB.class_get_property_list("Light3D", true):
		print("  ", p.name)
	print("DONE")
	quit()
