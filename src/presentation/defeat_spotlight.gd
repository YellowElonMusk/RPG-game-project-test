## The Defeat spotlight (GDD sprite-camera-presentation "Defeat", AC-49;
## ADR-0005 §3; story 053): one soft, wide, neutral overhead `SpotLight3D`
## aimed straight down at the party row's formation centre, plus the visible
## pool it leaves on the ground (the battle set is a painted canvas backdrop,
## so the pool quad is what the player actually sees).
##
## Both are culled to `DioramaStage.LAYER_SET`: the spotlight never lights an
## actor, so every party actor keeps exactly its Battle key and rim (the
## `defeat` profile carries the Battle key/rim strengths). Its strength
## follows the Defeat blend's `p` through `set_progress()`, which the Battle
## mode drives from the end-of-fight hold's own mode-time clock, so it
## freezes under the Menu with everything else in the mode. Every value comes
## from `PresentationConfig` (`defeat_spotlight_*`).
##
## Usage example:
## [codeblock]
## var spot := DefeatSpotlight.new()
## stage.add_child(spot)
## spot.setup(config)
## spot.aim_at(DefeatSpotlight.formation_centre(view.party_anchors()))
## spot.set_progress(DioramaStage.blend_progress(t, config.blend_defeat))
## [/codeblock]
class_name DefeatSpotlight
extends SpotLight3D

## The pool sits this far above the ground so it never z-fights the set (m).
const POOL_LIFT: float = 0.01

var _config: PresentationConfig
var _pool: MeshInstance3D
var _pool_material: StandardMaterial3D
var _progress: float = 0.0


## The ground-plane centre (y 0) of the party row: the mean of its foot
## anchors (stage space). `Vector3.ZERO` for an empty row.
## Example: [code]DefeatSpotlight.formation_centre([Vector3(-1, 0, -9), Vector3(1, 0, -9)])  # (0, 0, -9)[/code]
static func formation_centre(anchors: Array[Vector3]) -> Vector3:
	if anchors.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for a: Vector3 in anchors:
		sum += a
	var mean: Vector3 = sum / float(anchors.size())
	return Vector3(mean.x, 0.0, mean.z)


## Configures the light and builds its ground pool from `config`; starts
## off (`set_progress(0)`).
func setup(config: PresentationConfig) -> void:
	_config = config
	light_cull_mask = DioramaStage.LAYER_SET
	shadow_enabled = false
	light_color = config.defeat_spotlight_color
	spot_angle = config.defeat_spotlight_angle_degrees
	spot_range = config.defeat_spotlight_height * 2.0
	spot_angle_attenuation = 0.5  # soft edge
	rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # -Z points straight down
	if _pool == null:
		_pool_material = StandardMaterial3D.new()
		_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pool_material.albedo_texture = _pool_texture()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		_pool = MeshInstance3D.new()
		_pool.name = "Pool"
		_pool.mesh = plane
		_pool.material_override = _pool_material
		_pool.layers = DioramaStage.LAYER_SET
		_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pool.top_level = true
		add_child(_pool)
	set_progress(0.0)


## Places the light `defeat_spotlight_height` above `centre` (stage space,
## on the ground), aimed straight down, and the pool on the ground under it.
func aim_at(centre: Vector3) -> void:
	position = Vector3(centre.x, _config.defeat_spotlight_height, centre.z)
	rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	if _pool != null:
		var size: Vector2 = _config.defeat_spotlight_pool_size
		var parent_xform: Transform3D = get_parent().global_transform if get_parent() is Node3D \
				and is_inside_tree() else Transform3D.IDENTITY
		_pool.global_transform = parent_xform * Transform3D(
				Basis.from_scale(Vector3(size.x, 1.0, size.y)),
				Vector3(centre.x, POOL_LIFT, centre.z))


## Where the light's axis meets the ground plane (y 0), in the parent's
## (the stage's) space: the spotlight's ground-plane centre (AC-49).
func ground_centre() -> Vector3:
	var dir: Vector3 = -transform.basis.z
	if absf(dir.y) < 1e-9:
		return Vector3(position.x, 0.0, position.z)
	var t: float = -position.y / dir.y
	return position + dir * t


## Sets the spotlight's strength to the Defeat blend's `p` (0 = off, 1 =
## full `defeat_spotlight_energy` and pool strength).
func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	visible = _progress > 0.0
	light_energy = _config.defeat_spotlight_energy * _progress if _config != null else 0.0
	if _pool_material != null:
		var c: Color = _config.defeat_spotlight_color
		_pool_material.albedo_color = Color(c.r, c.g, c.b, _config.defeat_spotlight_pool_strength * _progress)
	if _pool != null:
		_pool.visible = visible


## The current blend progress (0-1).
func progress() -> float:
	return _progress


static var _pool_tex: Texture2D


## A soft round falloff (white; the material tints it).
static func _pool_texture() -> Texture2D:
	if _pool_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_pool_tex = tex
	return _pool_tex
