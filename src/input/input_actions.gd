## The Input System's action vocabulary (ADR-0003 Key Interfaces; GDD
## input-system.md rule 1). `StringName` constants only -- no other script may
## hardcode an action name literal outside this file and the bindings data
## (ADR-0003 Implementation Guidelines).
class_name InputActions
extends RefCounted

## `move_*` are binding-side sub-actions only: they drive `get_move_vector()`
## and are never emitted as `action_pressed` / `action_released` (ADR-0003 §8;
## story 001 pinned reading).
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"

## The seven discrete actions (GDD rule 1).
const CONFIRM: StringName = &"confirm"
const CANCEL: StringName = &"cancel"
const MENU: StringName = &"menu"
const INSPECT: StringName = &"inspect"
const PAGE_LEFT: StringName = &"page_left"
const PAGE_RIGHT: StringName = &"page_right"
const FAST_FORWARD: StringName = &"fast_forward"

## `nav_*` are derived menu-repeat steps (GDD rule 5; story 018). Never bound
## in the bindings data, and emitted as `action_pressed` only, with no
## `action_released` (ADR-0003 §8).
const NAV_UP: StringName = &"nav_up"
const NAV_DOWN: StringName = &"nav_down"
const NAV_LEFT: StringName = &"nav_left"
const NAV_RIGHT: StringName = &"nav_right"

## Every discrete action a default binding triple may name (excludes `move_*`
## and `nav_*`).
const DISCRETE: Array[StringName] = [
	CONFIRM, CANCEL, MENU, INSPECT, PAGE_LEFT, PAGE_RIGHT, FAST_FORWARD,
]

## The four `move_*` sub-actions a default binding triple may name.
const MOVE: Array[StringName] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]
