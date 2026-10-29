## The shared per-frame pathfinder budget (ADR-0012 §5 "Query budget"; GDD
## `design/gdd/overworld-exploration-encounters.md` rule 5). Notice searches,
## chase repaths and Returning paths all draw from one pool of `per_frame`
## grants per frame. A **round-robin cursor** serves the oldest deferred
## request first, whatever the marker order, so with N requesters every one
## is served within `ceil(N / per_frame)` frames (AC-9j).
##
## Pure `RefCounted`, injected into `SymbolBrain.step()`; the owner calls
## `begin_frame()` once per overworld frame before stepping any symbol.
class_name QueryBudget
extends RefCounted

## Grants per frame (`OverworldConfig.repath_per_frame_max`).
var per_frame: int = 0

## Frames begun so far.
var frame: int = 0

## Grants handed out since the last `begin_frame()` (spy for AC-9h, AC-10a).
var granted_this_frame: int = 0

## Grants handed out since creation.
var granted_total: int = 0

## The most grants handed out on any single frame.
var max_granted_in_a_frame: int = 0

## Deferred requester ids, oldest first (the round-robin queue).
var _queue: Array[int] = []
## Ids at the head of the queue that this frame's slots are held for.
var _reserved: Dictionary[int, bool] = {}
## How many of this frame's slots `begin_frame()` reserved.
var _reserved_slots: int = 0
## Grants handed to requesters that were not waiting in the queue.
var _free_granted: int = 0


## `p_per_frame` is `cfg.repath_per_frame_max`.
func _init(p_per_frame: int) -> void:
	per_frame = maxi(0, p_per_frame)


## Starts a new frame: resets the per-frame count and holds this frame's
## slots for the oldest deferred requesters. A reserved requester that did
## not ask last frame (it no longer needs a query) leaves the queue.
func begin_frame() -> void:
	for id: int in _reserved:
		_queue.erase(id)
	_reserved.clear()
	frame += 1
	granted_this_frame = 0
	_free_granted = 0
	_reserved_slots = mini(per_frame, _queue.size())
	for i in _reserved_slots:
		_reserved[_queue[i]] = true


## Asks for one query this frame on behalf of `requester_id` (a stable id
## per symbol, e.g. its brain's instance id). Returns `true` when granted;
## `false` defers it -- the requester joins the back of the queue once and
## keeps its place until served.
func request(requester_id: int) -> bool:
	if _reserved.has(requester_id):
		_reserved.erase(requester_id)
		_queue.erase(requester_id)
		_grant()
		return true
	var free: int = per_frame - _reserved_slots - _free_granted
	if free > 0 and not _queue.has(requester_id):
		_free_granted += 1
		_grant()
		return true
	if not _queue.has(requester_id):
		_queue.append(requester_id)
	return false


## Number of requesters currently deferred.
func waiting() -> int:
	return _queue.size()


func _grant() -> void:
	granted_this_frame += 1
	granted_total += 1
	max_granted_in_a_frame = maxi(max_granted_in_a_frame, granted_this_frame)
