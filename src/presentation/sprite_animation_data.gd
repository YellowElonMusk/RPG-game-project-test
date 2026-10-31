## One authored animation of a sprite set in one facing (GDD rule 10 and
## rule 9; ADR-0005 §1 and §9; stories 018, 062, 066). Pure data: the boot
## validators in `PresentationValidators` check it, and the replay formulas
## (ADR-0006 §1 `windup`/`ko_landing`) read the same frame data through
## `impact_seconds()` and `land_seconds()`.
##
## Usage example:
## [codeblock]
## var anim := SpriteAnimationData.new()
## anim.animation_id = &"attack"
## anim.facing = &"front"
## anim.fps = 10.0
## anim.frame_durations = PackedFloat32Array([1, 1, 2, 1])
## anim.impact_frame = 3
## print(anim.impact_seconds())  # 0.4 (w_i)
## [/codeblock]
class_name SpriteAnimationData
extends Resource

## Marks `impact_frame` / `land_frame` as not authored.
const NO_FRAME: int = -1

## The animation's role: `idle`, `attack`, `defend`, `hit`, `knockout`,
## `victory`, `intro`, `status`, `heal`, or `move` for a move-specific one.
@export var animation_id: StringName = &""
## The facing this art is drawn for: `front` or `back`.
@export var facing: StringName = &"front"
## For a move-specific animation (`animation_id == &"move"`): the move's
## display name it is keyed by (GDD Open Question 17). Empty otherwise.
@export var move_name: String = ""
## Base frame rate at 1x, in frames per second.
@export var fps: float = 10.0
## Each frame's relative duration (Godot `SpriteFrames` convention): a frame
## lasts `frame_durations[i] / fps` seconds at 1x.
@export var frame_durations: PackedFloat32Array = PackedFloat32Array()
## The 0-based frame where an action animation's hit lands; `NO_FRAME` if
## not authored. Valid range: `0 .. frame_count() - 1`.
@export var impact_frame: int = NO_FRAME
## The 0-based frame where a `knockout` slump lands (rule 9); `NO_FRAME` if
## not authored. Valid range: `0 .. frame_count() - 1`.
@export var land_frame: int = NO_FRAME
## True when this animation must never be shown by mirroring the opposite
## facing (rule 3; story 005).
@export var no_mirror: bool = false
## The art: one horizontal strip of `frame_count()` equal-width frames, as
## SpriteForge exports it (`<out_dir>/<short>_<anim>.png`, asset list §7).
## Null for frame-data-only sets (tests); `SpriteSetData.build_sprite_frames()`
## skips them.
@export var strip: Texture2D


## Number of frames.
func frame_count() -> int:
	return frame_durations.size()


## Frame `index`'s region of `strip`, in texels: `strip` split into
## `frame_count()` equal columns. `Rect2i()` without a strip or for an index
## outside `0 .. frame_count() - 1`.
func frame_region(index: int) -> Rect2i:
	if strip == null or index < 0 or index >= frame_count():
		return Rect2i()
	var w: int = strip.get_width() / frame_count()
	return Rect2i(index * w, 0, w, strip.get_height())


## True for an action animation (`attack`, `defend` or a move-specific one),
## which must carry a valid `impact_frame` (rule 10).
func is_action() -> bool:
	return animation_id == &"attack" or animation_id == &"defend" or animation_id == &"move"


## Seconds at 1x from the animation's start until frame `frame_index`
## starts: `sum(frame_durations[0 .. frame_index-1]) / fps`. Returns -1.0
## for an index outside `0 .. frame_count() - 1` or a non-positive `fps`.
func seconds_before(frame_index: int) -> float:
	if frame_index < 0 or frame_index >= frame_count() or fps <= 0.0:
		return -1.0
	var ticks: float = 0.0
	for i: int in range(frame_index):
		ticks += frame_durations[i]
	return ticks / fps


## The wind-up to the impact at 1x (`w_i`, GDD `replay_time`); -1.0 if invalid.
func impact_seconds() -> float:
	return seconds_before(impact_frame)


## The knockout slump's landing time at 1x (`k_i`, GDD `replay_time`); -1.0 if invalid.
func land_seconds() -> float:
	return seconds_before(land_frame)


## The animation's whole length at 1x, in seconds; 0.0 for a non-positive `fps`.
func duration_seconds() -> float:
	if fps <= 0.0:
		return 0.0
	var ticks: float = 0.0
	for d: float in frame_durations:
		ticks += d
	return ticks / fps
