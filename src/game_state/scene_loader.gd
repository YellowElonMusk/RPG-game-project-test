## Injected collaborator (ADR-0002 Key Interfaces, plus the story-001
## interface additions below — draft §2 item 6, recorded here for the batched
## technical-director annotation to ADR-0002). The production implementation
## resolves a mode's `PackedScene` path from `TransitionConfig` and owns
## `ModeHost`/`OverlayHost`; tests stub every method. Base bodies here are
## safe no-op defaults so a test double only needs to override what it drives.
class_name SceneLoader extends RefCounted

enum SwapStatus { PENDING, DONE, FAILED }

## Starts a mode swap. Synchronous production work happens here or across
## subsequent `poll_swap()` calls.
func begin_swap(_from: int, _to: int, _payload: RefCounted) -> void:
	pass


## Polled once per `tick()` while `phase == SWAP`. SWAP ends on the first
## `DONE` (or `FAILED`, which triggers rollback).
func poll_swap() -> SwapStatus:
	return SwapStatus.DONE


## Restores the source mode after a swap failure (AC-10).
func rollback_swap() -> void:
	pass


## Interface addition (story-001): pushes an overlay scene onto `OverlayHost`.
func push_overlay(_kind: int, _payload: RefCounted) -> void:
	pass


## Interface addition: pops the top overlay scene from `OverlayHost`.
func pop_overlay() -> void:
	pass


## Interface addition: toggles `ModeHost.process_mode` for the Menu's time
## stop (ADR-0002 §5).
func set_mode_time_stopped(_stopped: bool) -> void:
	pass


## Interface addition: frees the detached Overworld instance explicitly
## (ADR-0002 §4 — Retreat, Quit to Title, `GameRoot._exit_tree()`).
func free_frozen_overworld() -> void:
	pass


## Interface addition: the live `GameMode` node currently under `ModeHost`, or
## `null` if none.
func current_mode_node() -> Node:
	return null
