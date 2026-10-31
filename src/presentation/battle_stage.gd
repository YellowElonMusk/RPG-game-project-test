## One battle stage's authored camera and formation data (GDD `battle_framing`,
## ADR-0005 §6 and §9; stories 022, 046). Pure data: `BattleFraming` validates
## it at load, `DioramaStage.configure_battle_camera()` places the level
## battle camera from it. Every value here is stage content, never a literal
## in a script (Control Manifest, Stages and lighting).
class_name BattleStage
extends Resource

## The stage's content id (named in every validation error).
@export var stage_id: StringName
## Whether this is a boss stage (adds `horizon_frac >= sky_share_min`).
@export var is_boss: bool = false
## Camera height above the ground plane, in metres (`h_cam`).
@export var h_cam: float = 1.6
## Where the horizon sits, as a share of the frame height from the top
## (`horizon_frac`; GDD range 0.15-0.40). Set by the lens shift.
@export_range(0.15, 0.40, 0.01) var horizon_frac: float = 0.30
## The view depth at which the background blur begins, in metres (near blur
## is always off). Must be at least `z_far + dof_margin`.
@export var background_blur_begin: float = 16.0
## The largest idle frame (texels, w x h) any actor standing on a slot uses;
## every slot's quad is checked at this size (GDD: "the full frame of the
## actor's idle").
@export var actor_frame_size: Vector2i = Vector2i(48, 64)
## The per-slot depth stagger, in metres (GDD Edge Cases, "two actors at
## exactly the same depth"): slot `i` stands `i * slot_depth_step` deeper
## than its authored base depth.
@export var slot_depth_step: float = 0.05
## The set light's authored native energy (`B_native`, GDD
## `set_brightness_and_blur`); every battle-family state scales it by `k_state`.
@export var set_energy_native: float = 1.0
## The sky card's authored native energy (`B_sky_native`).
@export var sky_energy_native: float = 1.0
## Each slot's authored ground position: `x` is the lateral offset (m, +x
## right), `y` the base view depth (m) before the stagger.
@export var slots: Array[Vector2] = []
## The stage-space bounds of every piece of set geometry tagged as an
## occluder (a pillar, a counter; GDD `battle_framing`, "Visible share";
## story 047). Same space as `slot_anchor()`: the ground is `y = 0`, the
## camera looks down -Z. Each must enclose the scene's matching node tagged
## `DioramaStage.OCCLUDER_TAG`. Empty when the set has none in front of the
## actors (the painted backdrop is a canvas layer, never an occluder).
@export var occluders: Array[AABB] = []


## Slot `index`'s view depth `z`, stagger included (GDD `battle_framing`:
## "per-slot stagger included").
func slot_depth(index: int) -> float:
	return slots[index].y + slot_depth_step * float(index)


## Slot `index`'s foot anchor in stage space: on the ground plane, `z` metres
## in front of the camera (Godot's forward is -Z).
func slot_anchor(index: int) -> Vector3:
	return Vector3(slots[index].x, 0.0, -slot_depth(index))


## The level battle camera's stage-space transform: `h_cam` above the ground,
## pitch 0, looking down -Z (ADR-0005 §6). Never changes in a fight.
func camera_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, h_cam, 0.0))
