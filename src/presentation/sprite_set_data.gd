## One battle sprite set: its animations per facing and the facings it is
## used in (GDD rule 10; ADR-0005 §9; stories 018, 062, 066). Records name a
## set by `sprite_set_id`; shipped sets live under
## `data/presentation/sprite_sets/`. `resolve()` is rule 10's runtime
## fallback for optional animations.
##
## Usage example:
## [codeblock]
## var r := sprite_set.resolve(&"status", &"front", "", func(m: String) -> void: push_warning(m))
## if r.placeholder: show_checkerboard()
## [/codeblock]
class_name SpriteSetData
extends Resource

## Rule 10: required in every battle sprite set, in each facing it is used in.
const REQUIRED_BATTLE: Array[StringName] = [&"idle", &"attack", &"defend", &"hit", &"knockout"]
## Rule 10: the squad fanfare pose, required in squad sets.
const VICTORY: StringName = &"victory"
## The facing a squad set's `victory` is required in.
const VICTORY_FACING: StringName = &"back"
## Rule 10: the boss entrance, required in sets an encounter names as boss.
const INTRO: StringName = &"intro"
## The facing a boss set's `intro` is required in.
const INTRO_FACING: StringName = &"front"
## The move-specific animation role.
const MOVE: StringName = &"move"
## Rule 10's optional-fallback table: missing key falls back to the value;
## `&""` means "hold the current pose" (no reaction).
const OPTIONAL_FALLBACK: Dictionary = {&"move": &"attack", &"status": &"hit", &"heal": &""}


## The result of `resolve()`: what the sprite actually shows.
class Resolution extends RefCounted:
	## The animation to show (null when `placeholder` or `hold_current`).
	var animation: SpriteAnimationData = null
	## True when the opposite facing's art is shown mirrored.
	var mirrored: bool = false
	## True when the checkerboard placeholder is shown (debug-only path).
	var placeholder: bool = false
	## True when the combatant keeps its current pose (`heal` fallback).
	var hold_current: bool = false
	## True when rule 10's fallback (or the placeholder) replaced the request.
	var fell_back: bool = false


## The set's content id (named in every validation error).
@export var set_id: StringName = &""
## True for a squad (player character) set: `victory` is then required.
@export var is_squad: bool = false
## The facings this set is shown in (`front`, `back`).
@export var facings_used: Array[StringName] = [&"front"]
## Every authored animation, one entry per role (or move) and facing.
@export var animations: Array[SpriteAnimationData] = []


## The opposite of `facing` (`front` <-> `back`).
static func opposite_facing(facing: StringName) -> StringName:
	return &"back" if facing == &"front" else &"front"


## The authored animation for `animation_id` in `facing` (and `move_name`
## for a move-specific one), or null.
func find(animation_id: StringName, facing: StringName, move_name: String = "") -> SpriteAnimationData:
	for anim: SpriteAnimationData in animations:
		if anim != null and anim.animation_id == animation_id and anim.facing == facing \
				and (animation_id != MOVE or anim.move_name == move_name):
			return anim
	return null


## True when `animation_id` can be shown in `facing`: authored there, or
## authored in the opposite facing without `no_mirror` (rule 3 / rule 10).
func has_in_facing(animation_id: StringName, facing: StringName, move_name: String = "") -> bool:
	if find(animation_id, facing, move_name) != null:
		return true
	var other := find(animation_id, opposite_facing(facing), move_name)
	return other != null and not other.no_mirror


## Rule 10 at runtime: the authored art, else the mirrored opposite facing
## (unless `no_mirror`), else the optional fallback in the same facing, else
## the checkerboard placeholder. Every substitution calls `warn` exactly once
## with a message naming the set and the animation; a direct or legally
## mirrored hit never warns. A `no_mirror` animation is never mirrored.
func resolve(animation_id: StringName, facing: StringName, move_name: String,
		warn: Callable) -> Resolution:
	var r := _lookup(animation_id, facing, move_name)
	if r != null:
		return r
	r = Resolution.new()
	r.fell_back = true
	if OPTIONAL_FALLBACK.has(animation_id):
		var target: StringName = OPTIONAL_FALLBACK[animation_id]
		if target == &"":
			r.hold_current = true
		else:
			var fb := _lookup(target, facing, "")
			if fb != null:
				fb.fell_back = true
				r = fb
			else:
				r.placeholder = true
		warn.call("Sprite set %s: optional animation %s (%s) missing; fell back to %s." % [
				set_id, label_for(animation_id, move_name), facing,
				"current pose" if r.hold_current else ("placeholder" if r.placeholder else String(target))])
		return r
	r.placeholder = true
	warn.call("Sprite set %s: animation %s (%s) missing; showing placeholder (validation skipped?)." % [
			set_id, label_for(animation_id, move_name), facing])
	return r


func _lookup(animation_id: StringName, facing: StringName, move_name: String) -> Resolution:
	var direct := find(animation_id, facing, move_name)
	if direct != null:
		var r := Resolution.new()
		r.animation = direct
		return r
	var other := find(animation_id, opposite_facing(facing), move_name)
	if other != null and not other.no_mirror:
		var m := Resolution.new()
		m.animation = other
		m.mirrored = true
		return m
	return null


## A display label for an animation: its id, or `move` plus the move name.
static func label_for(animation_id: StringName, move_name: String) -> String:
	return "%s '%s'" % [animation_id, move_name] if animation_id == MOVE else String(animation_id)
