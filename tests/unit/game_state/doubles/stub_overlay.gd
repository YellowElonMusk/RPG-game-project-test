## Subclasses `GameOverlay`, same note as `StubOverworldMode`.
class_name StubOverlay extends GameOverlay

## Story 010: counts `handle_action` calls, so a test can prove nothing (or
## exactly one thing) reached this overlay.
var handle_action_count: int = 0
var last_action: StringName = &""
var last_pressed: bool = false

## Story 030: records what the real `ModeHostSceneLoader.push_overlay()`
## handed to `setup()`, so a test using the real loader (no
## `last_push_overlay_payload` field to read, unlike `StubSceneLoader`) can
## still see the payload — e.g. the stand-in Menu overlay in
## `game_state_defeat_prompt_focus_test.gd`.
var last_setup_machine: GameStateMachine = null
var last_setup_payload: RefCounted = null


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	last_setup_machine = machine
	last_setup_payload = payload


func handle_action(action: StringName, pressed: bool) -> bool:
	handle_action_count += 1
	last_action = action
	last_pressed = pressed
	return false
