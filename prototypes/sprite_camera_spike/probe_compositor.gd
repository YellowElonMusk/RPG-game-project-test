# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree

# Throwaway probe: what does CompositorEffect expose on 4.7.2 for reading
# glow before tonemapping? Headless ClassDB introspection only, no rendering.

func _initialize() -> void:
	print("=== CompositorEffect ===")
	if ClassDB.class_exists("CompositorEffect"):
		for m in ClassDB.class_get_method_list("CompositorEffect", true):
			print("  method: ", m.name)
		for p in ClassDB.class_get_property_list("CompositorEffect", true):
			print("  prop: ", p.name, " type=", p.type)
	else:
		print("  CompositorEffect does not exist")

	print("=== EffectCallbackType enum ===")
	var consts := ClassDB.class_get_enum_constants("CompositorEffect", "EffectCallbackType", true)
	for c in consts:
		print("  ", c, " = ", ClassDB.class_get_integer_constant("CompositorEffect", c))

	print("=== RenderSceneBuffers ===")
	if ClassDB.class_exists("RenderSceneBuffers"):
		for m in ClassDB.class_get_method_list("RenderSceneBuffers", true):
			print("  method: ", m.name)

	print("=== RenderSceneBuffersRD ===")
	if ClassDB.class_exists("RenderSceneBuffersRD"):
		for m in ClassDB.class_get_method_list("RenderSceneBuffersRD", true):
			print("  method: ", m.name)
	else:
		print("  RenderSceneBuffersRD does not exist")

	print("=== Compositor ===")
	if ClassDB.class_exists("Compositor"):
		for p in ClassDB.class_get_property_list("Compositor", true):
			print("  prop: ", p.name)

	print("=== RENDERING_INFO / PIPELINE_COMPILATIONS ===")
	for c in ["RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS","RENDERING_INFO_PIPELINE_COMPILATIONS_MESH","RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE","RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW","RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION"]:
		print("  ", c, " exists=", ClassDB.class_get_integer_constant("RenderingServer", c) if ClassDB.class_has_integer_constant("RenderingServer", c) else "NO")
	for c in ["PIPELINE_COMPILATIONS_CANVAS","PIPELINE_COMPILATIONS_MESH","PIPELINE_COMPILATIONS_SURFACE","PIPELINE_COMPILATIONS_DRAW","PIPELINE_COMPILATIONS_SPECIALIZATION"]:
		print("  Performance.", c, " exists=", ClassDB.class_has_integer_constant("Performance", c))

	print("DONE")
	quit()
