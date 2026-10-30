## Shared fixture for the interaction stories (011-016): an `OverworldMode`
## on the shipped segment map (its NPC and clue poster included) plus any
## extra markers a test places, on a Game State machine idle in the
## Overworld so `say()` can open the line overlay. Caller frees the mode.
class_name ProbeFixture
extends RefCounted

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const SEGMENT: String = "res://data/maps/paris_segment_placeholder.tscn"
## An open stretch of the segment's bottom row, clear of every marker.
const OPEN_SPOT: Vector2 = Vector2(12.0, 14.5)
const ENC_STATIC: String = "enc_fixture_static"


## A mode on the segment with `extras` (markers at their set positions)
## added to the map before it loads. `machine` defaults to a fresh one idle
## in the Overworld.
static func make_mode(extras: Array = [], machine: GameStateMachine = null) -> OverworldMode:
	if machine == null:
		machine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var map: OverworldMap = (load(SEGMENT) as PackedScene).instantiate() as OverworldMap
	for marker: Node3D in extras:
		map.add_child(marker)
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	var catalog := RecordCatalogDouble.new()
	for id: String in ["enc_paris_clerks_west", "enc_paris_clerks_east", ENC_STATIC]:
		catalog.add(&"encounter", RecordCatalogDouble.make_encounter(id))
	mode.encounter_catalog = catalog
	mode.load_map(map)
	# The load's name card (story 111) would hold barks back; let it clear.
	mode.tick_timed_text(60.0)
	return mode


## A marker of `type` at ground `at`.
static func npc(at: Vector2, id: StringName = &"npc_fixture") -> NpcSpawn:
	var m := NpcSpawn.new()
	m.marker_id = id
	m.line = "Fixture line."
	m.position = Vector3(at.x, 0.0, at.y)
	return m


static func camp(at: Vector2, id: StringName = &"camp_fixture") -> CampSpot:
	var m := CampSpot.new()
	m.marker_id = id
	m.camp_id = "camp_fixture"
	m.return_entry_id = &"from_town"
	m.position = Vector3(at.x, 0.0, at.y)
	return m


static func gag(at: Vector2, response: GagInteractable.Response = GagInteractable.Response.LINE,
		id: StringName = &"gag_fixture") -> GagInteractable:
	var m := GagInteractable.new()
	m.marker_id = id
	m.response = response
	m.text = "Fixture gag."
	m.alt_text = "Fixture gag, again."
	m.rumour_id = "rumour_fixture"
	m.position = Vector3(at.x, 0.0, at.y)
	return m


static func static_symbol(at: Vector2) -> EncounterSymbol:
	var m := EncounterSymbol.new()
	m.encounter_id = ENC_STATIC
	m.symbol_id = "sym_fixture_static"
	m.patrol_path = PackedVector2Array([at])
	m.is_static = true
	m.start_on = EncounterSymbol.StartOn.CONFIRM
	m.position = Vector3(at.x, 0.0, at.y)
	return m


## Places the leader at `at` facing `facing`.
static func stand(mode: OverworldMode, at: Vector2, facing: Vector2) -> void:
	mode.set_leader_position(at)
	mode.set_leader_facing(facing)
