## A system that persists state (ADR-0009 §3). It owns its section's schema
## and migrations, stores catalog IDs never definitions, stages without side
## effects and commits without failing. Registered in
## `src/boot/save_bootstrap.gd`.
@abstract class_name SaveParticipant extends RefCounted


## Stable snake_case key; never renamed.
@abstract func save_key() -> StringName


@abstract func schema_version() -> int


## JSON-safe values only (Vector2 as [x, y], StringName as String).
@abstract func capture() -> Dictionary


## Decodes and resolves `data` (already migrated). No side effects.
@abstract func stage(data: Dictionary, reader: SaveReader) -> SaveStage


## Applies a successful stage. Must not fail.
@abstract func commit(staged: SaveStage) -> void


## New Game, and before every commit.
@abstract func reset_to_new_game() -> void


## Step-wise migration to `schema_version()`. The base has no steps.
func migrate(data: Dictionary, _from_version: int) -> Dictionary:
	return data


## Fields merged into the slot summary (optional).
func summary_fields() -> Dictionary:
	return {}
