## A real `BattleMode` (real `BattleCore`, view, HUD and replay controller)
## driven by a real `GameStateMachine` over a `StubSceneLoader` whose current
## mode node is that Battle mode (ADR-0002 §7, ADR-0006 §5). Retry
## (`choose_retry`), Retreat (`choose_retreat`, a camp is registered) and
## Quit (Menu + `request_transition(TITLE)`) all run the machine's real
## transition rows, so `transition_started` and `restore_start_snapshot()`
## reach the mode exactly as in the game. The test drives mode time itself
## with `step()`.
##
## Usage example:
## [codeblock]
## var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
## auto_free(h.mode)
## h.reveal()
## h.step(10)
## [/codeblock]
class_name BattleModeHarness
extends RefCounted

const SCENE: String = "res://src/battle/battle_mode.tscn"
const PROFILES_DIR: String = "res://data/presentation/profiles"
## One frame of mode time.
const DT: float = 1.0 / 60.0

var machine: GameStateMachine
var loader: StubSceneLoader
var game_log: SpyGameStateLog
var mode: BattleMode
var stage: DioramaStage
var frame: int = 0
## Every profile id the stage resolved, in order (a spy on the stage's door).
var profile_requests: Array[StringName] = []
## Every recorded controller event: {"event": String, "frame": int}.
var events: Array[Dictionary] = []


## Builds the machine, enters Battle with `party` against one Clerk (or the
## Bureaucratia boss pair when `is_boss`), and stops just before the reveal
## (`reveal()` finishes the swap and opens the gate). `settings` is injected
## as the mode's `presentation_settings` before `setup()`.
static func create(host: Node, party: Array[Combatant], is_boss: bool = false,
		settings: PresentationSettings = null) -> BattleModeHarness:
	var h := BattleModeHarness.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	h.machine = env["machine"]
	h.loader = env["loader"]
	h.game_log = env["log"]
	GameStateFixtures.track(h.machine)
	h.machine.register_camp("camp_a")
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "harness_fight"
	descriptor.enemy_ids = PackedStringArray(["enemy_supervisor", "enemy_clerk"]) if is_boss \
			else PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.is_boss = is_boss
	descriptor.can_flee = true
	descriptor.retreat_allowed = true
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = party
	h.mode = (load(SCENE) as PackedScene).instantiate() as BattleMode
	if settings != null:
		h.mode.set(&"presentation_settings", settings)
	h.mode.setup(h.machine, payload)
	host.add_child(h.mode)
	h.mode.set_process(false)
	h.stage = h.mode.get_node(^"%DioramaStage")
	h.stage.set_process(false)
	h.stage.bind_profiles(h._resolve)
	h.stage.apply_profile(h._resolve(&"battle"), 0.0)
	h.profile_requests.clear()
	h._connect_recorders()
	h.loader.current_mode_node_value = h.mode
	h.machine.request_transition(GameStateMachine.Mode.BATTLE, payload)
	return h


## Finishes the swap into Battle (`transition_finished(BATTLE)` opens the
## reveal gate).
func reveal() -> void:
	run_machine_to_idle()


## Ticks the machine (and mode time alongside it) until it is IDLE.
func run_machine_to_idle(step_mode: bool = true) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(DT)
		if step_mode:
			step()
		ticks += 1


## Advances `n` frames of mode time.
func step(n: int = 1) -> void:
	for i: int in n:
		frame += 1
		mode.step_replay(DT)


## Presses and releases `action` through the mode; returns the press's result.
func press(action: StringName) -> bool:
	var consumed: bool = mode.handle_action(action, true)
	mode.handle_action(action, false)
	return consumed


## Applies `dmg` to `target` and emits an Attack outcome on the live core.
func emit_hit(actor: Combatant, target: Combatant, dmg: int) -> void:
	var removed: int = target.take_damage(dmg)
	mode.battle.action_resolved.emit(BattleOutcome.new(actor, "Attack", Move.Category.ATTACK, target,
			-removed, 0, target.is_knocked_out(), mode.battle.round_number))


## The machine's pending outcome (-1 when none).
func pending_outcome() -> int:
	return int(machine.get_debug_state()["pending_outcome"])


## Frames at which `event_name` fired.
func frames_of(event_name: String) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in events:
		if e["event"] == event_name:
			out.append(int(e["frame"]))
	return out


## Events recorded from index `from` on, by name.
func event_names_since(from: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(from, events.size()):
		out.append(String(events[i]["event"]))
	return out


func _resolve(id: StringName) -> LightingProfile:
	profile_requests.append(id)
	return load(PROFILES_DIR.path_join("%s.tres" % id)) as LightingProfile


func _connect_recorders() -> void:
	var r: BattleReplayController = mode.replay
	for sig: String in ["replay_started", "replay_finished", "replay_cancelled", "display_resynced"]:
		r.connect(sig, _record.bind(sig))
	r.beat_started.connect(_record.bind("beat_started").unbind(1))
	r.beat_impact.connect(_record.bind("beat_impact").unbind(1))
	r.beat_finished.connect(_record.bind("beat_finished").unbind(1))
	r.hold_started.connect(_record.bind("hold_started").unbind(2))
	r.hold_finished.connect(_record.bind("hold_finished").unbind(1))
	r.round_advanced_after_replay.connect(_record.bind("round").unbind(1))
	r.turn_started_after_replay.connect(_record.bind("turn").unbind(1))
	r.battle_ended_after_replay.connect(_record.bind("end").unbind(1))
	r.latch_changed.connect(_record_latch)


func _record(event_name: String) -> void:
	events.append({"event": event_name, "frame": frame})


func _record_latch(on: bool) -> void:
	_record("latch_on" if on else "latch_off")
