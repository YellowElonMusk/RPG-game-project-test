## Field-of-view math shared by the follow camera, the battle camera's
## framing and `PresentationConfig`'s load rules (GDD `follow_camera`,
## ADR-0005 §6). Kept free of references to those classes:
## `PresentationConfig` -> `FollowCamera` -> `PresentationConfig` was a
## script dependency cycle, and Godot never unloads cyclic scripts, so every
## process that loaded the config leaked them (and whatever they held) at exit.
##
## Usage example:
## [codeblock]
## var f_v_eff: float = FovMath.effective_vertical_fov_degrees(20.0, 4.0 / 3.0)
## [/codeblock]
class_name FovMath
extends RefCounted


## `F_v_eff` (GDD `follow_camera`): the vertical field of view actually
## shown. Fixed at `fov_degrees` at 16:9 and wider; below 16:9 the camera
## keeps the 16:9 horizontal view, so the vertical view grows.
static func effective_vertical_fov_degrees(p_fov_degrees: float, aspect: float) -> float:
	var widen: float = maxf(1.0, (16.0 / 9.0) / aspect)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(p_fov_degrees) * 0.5) * widen))
