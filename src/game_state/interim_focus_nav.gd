## INTERIM confirm/direction focus helper (story 030), tagged per its
## Implementation Notes: stands in for ADR-0008's `FocusScope`/`UiNavigator`,
## which do not exist yet, and for the Input System's `ui_*` re-injection
## (`production/epics/input-system/story-021-nav-pressed-only-reinjection.md`,
## Blocked). Deleted once either lands. A mode or overlay calls these two
## functions from its own `handle_action()`; this file never touches the
## scene tree outside `root`'s own subtree and never calls `Input` directly
## (unlike `UiNavigator`, which is the one file allowed to).
class_name InterimFocusNav extends RefCounted


## Routes a `confirm` press to whichever focused control sits inside `root`'s
## subtree: emits `pressed` on it if it is a `BaseButton`. Returns `true` if
## it did. `root` must be in the tree (its own `Viewport` is read fresh each
## call, never cached, since the focus owner changes independently of this
## helper).
static func route_confirm(root: Control) -> bool:
	var owner: Control = _focus_owner_in(root)
	if owner == null or not (owner is BaseButton):
		return false
	(owner as BaseButton).emit_signal(&"pressed")
	return true


## Routes a direction action (`nav_up`/`nav_down`/`nav_left`/`nav_right`) to
## `Control.find_valid_focus_neighbor()` from whichever focused control sits
## inside `root`'s subtree, and grabs focus on the neighbor if one exists.
## Returns `true` if focus moved.
static func route_direction(root: Control, side: Side) -> bool:
	var owner: Control = _focus_owner_in(root)
	if owner == null:
		return false
	var neighbor: Control = owner.find_valid_focus_neighbor(side)
	if neighbor == null:
		return false
	neighbor.grab_focus()
	return true


## The current focus owner, or `null` if there is none or it sits outside
## `root`'s subtree (so a background overlay never redirects focus actions
## meant for whatever is on top of it).
static func _focus_owner_in(root: Control) -> Control:
	var viewport: Viewport = root.get_viewport()
	if viewport == null:
		return null
	var owner: Control = viewport.gui_get_focus_owner()
	if owner == null or not root.is_ancestor_of(owner):
		return null
	return owner
