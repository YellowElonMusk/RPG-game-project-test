## Factories for this epic's payloads and config, plus the one shared path
## every test uses to reach a machine already in `OVERWORLD`. Thresholds come
## from the `TransitionConfig` fixture here, never literals.
class_name GameStateFixtures extends RefCounted


static func make_transition_config() -> TransitionConfig:
	var cfg := TransitionConfig.new()
	cfg.t_out = {
		&"fade": 0.2, &"battle_wipe": 0.3, &"battle_wipe_reverse": 0.3,
		&"retry_flash": 0.15, &"none": 0.0,
	}
	cfg.t_in = {
		&"fade": 0.2, &"battle_wipe": 0.25, &"battle_wipe_reverse": 0.25,
		&"retry_flash": 0.15, &"none": 0.0,
	}
	cfg.transition_budget = {
		&"fade": 0.6, &"battle_wipe": 0.6, &"battle_wipe_reverse": 0.6,
		&"retry_flash": 0.4, &"none": 0.0,
	}
	cfg.validate_enemy_ids_against_catalog = false
	return cfg


## Story 006: a `TransitionConfig` with exactly one row, for the
## `transition_time` formula test and as a valid-row baseline for the budget
## check test (`add_row` appends further rows). `budget` defaults to
## `t_out + t_in` (valid) when not given.
static func transition_config_with(transition_type: StringName, t_out: float,
		t_in: float, budget: float = -1.0) -> TransitionConfig:
	var cfg := TransitionConfig.new()
	add_row(cfg, transition_type, t_out, t_in, budget)
	return cfg


## Appends (or overwrites) one row on an existing `TransitionConfig`, in place.
## `budget` defaults to `t_out + t_in` (valid) when not given.
static func add_row(cfg: TransitionConfig, transition_type: StringName, t_out: float,
		t_in: float, budget: float = -1.0) -> void:
	cfg.t_out[transition_type] = t_out
	cfg.t_in[transition_type] = t_in
	cfg.transition_budget[transition_type] = budget if budget >= 0.0 else t_out + t_in


static func make_encounter_descriptor() -> EncounterDescriptor:
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "encounter_fixture_01"
	descriptor.enemy_ids = PackedStringArray(["clerk_01"])
	descriptor.battle_stage_id = "stage_fixture"
	descriptor.faction_id = "bureaucratia"
	descriptor.is_boss = false
	descriptor.can_flee = true
	descriptor.retreat_allowed = false
	return descriptor


## An opaque handle standing in for the Overworld's frozen state until
## Overworld Exploration & Encounters defines the real snapshot shape.
static func make_overworld_snapshot() -> RefCounted:
	return RefCounted.new()


static func valid_battle_entry() -> BattleEntryPayload:
	var payload := BattleEntryPayload.new()
	payload.descriptor = make_encounter_descriptor()
	payload.party = []
	return payload


static func make_ready_catalog() -> StubCatalog:
	var catalog := StubCatalog.new()
	catalog.state = ContentCatalogService.State.READY
	return catalog


## Builds a machine and its doubles, then drives it from `BOOT` to an idle
## `OVERWORLD` through the real Boot -> Title -> Overworld path (tick() for
## Boot's internal check, `request_transition()` for Title -> Overworld) —
## never a shortcut that sets `current_mode` directly. If `recorder` is given,
## every double is wired to it so a caller can `clear()` before its own
## scenario and get a clean, ordered array.
static func make_machine_in_overworld(recorder: SequenceRecorder = null) -> Dictionary:
	var loader := StubSceneLoader.new(recorder)
	var presenter := StubTransitionPresenter.new(recorder)
	var cfg := make_transition_config()
	var catalog := make_ready_catalog()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	if recorder != null:
		recorder.attach(machine)

	# Boot -> Title (fade): driven only by tick(); catalog is already READY.
	machine.tick(0.0)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	# Title -> Overworld (fade): the one legal request_transition() pair from Title.
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	return {
		"machine": machine, "loader": loader, "presenter": presenter, "config": cfg,
		"catalog": catalog, "quit_spy": quit_spy, "log": game_log,
	}
