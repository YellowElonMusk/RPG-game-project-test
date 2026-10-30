## Story 093, AC-35 (GDD rule 15): after any frame step, world state's map,
## position and facing equal the leader's; no other world-state field
## changes on a frame with no event; and the Overworld never calls the save
## writer (it holds no save service at all: saves happen through Game
## State's safe moments and the Camp, ADR-0009 §4). WorldState emits no
## change signals, so there is nothing to spy on there.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0


func test_every_frame_mirrors_map_position_and_facing() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var ws: WorldState = mode.world_state
	for input: Vector2 in [Vector2.RIGHT, Vector2.RIGHT, Vector2.DOWN, Vector2.ZERO, Vector2.LEFT]:
		mode.step_frame(_DT, input)
		assert_str(ws.map_id).is_equal(mode.get_map().map_id)
		assert_vector(ws.party_pos).is_equal(mode.get_leader_position())
		assert_vector(ws.party_facing).is_equal(mode.get_leader_facing())


func test_other_fields_do_not_change_on_plain_frames() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var ws: WorldState = mode.world_state
	ws.set_flag("fixture_flag")
	ws.mark_resolved("map_fixture", "sym_fixture", WorldState.Respawn.NEVER)
	var before: Dictionary = _without_party(ws.to_dict())
	for i: int in 30:
		mode.step_frame(_DT, Vector2.RIGHT if i < 15 else Vector2.ZERO)
	assert_dict(_without_party(ws.to_dict())).is_equal(before)


func test_the_overworld_holds_no_save_writer() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	for prop: Dictionary in mode.get_property_list():
		assert_bool(String(prop["class_name"]) == "SaveService").override_failure_message(
				"OverworldMode.%s is a SaveService" % prop["name"]).is_false()
	var source: String = (mode.get_script() as GDScript).source_code
	assert_bool(source.contains("save_to_slot")).is_false()


func _without_party(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	out.erase("party_pos")
	out.erase("party_facing")
	return out
