## Story 015, AC-7e (GDD rule 3 Prompt, UI Requirements): on every frame of
## a scripted walk past 3 targets, the interact prompt is drawn above
## exactly one target, the `probe()` result, or hidden when there is none.
## It is hidden while a transition, an overlay or a redirect runs. Uses the
## assembled `overworld_mode.tscn` (view included) on the segment map.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _SCENE: String = "res://src/overworld/overworld_mode.tscn"
const _DT: float = 1.0 / 60.0


func test_prompt_tracks_the_probe_result_on_every_frame_of_a_walk() -> void:
	var ctx: Dictionary = _make()
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var map: OverworldMap = mode.get_map()
	# A third target beside the NPC and the clue poster.
	var extra := GagInteractable.new()
	extra.marker_id = &"gag_fixture_extra"
	extra.text = "Extra."
	extra.position = Vector3(12.0, 0.0, 14.5)
	map.add_child(extra)
	var targets: Array = [map.npc_spawns()[0], map.gags()[0], extra]
	var seen: Dictionary = {}
	for target: Node3D in targets:
		var at: Vector2 = OverworldMap.ground_position_of(target, map)
		# Walk east along a line 0.5 m south of the target, from 3 m before
		# it to 3 m after, facing it diagonally.
		for i: int in 60:
			var x: float = at.x - 3.0 + 6.0 * float(i) / 59.0
			mode.set_leader_position(Vector2(x, at.y + 0.5))
			mode.set_leader_facing(Vector2.UP)
			view._process(_DT)
			var probed: Object = mode.probe()
			assert_bool(view.interact_target == probed).override_failure_message(
					"frame %d near %s: prompt on %s, probe() %s" % [i, target.name, view.interact_target, probed]).is_true()
			assert_bool(view.get_interact_label().visible).is_equal(probed != null)
			if probed != null:
				seen[probed] = true
	for target: Node3D in targets:
		assert_bool(seen.has(target)).override_failure_message("never prompted for %s" % target.name).is_true()


func test_prompt_is_drawn_above_its_target() -> void:
	var ctx: Dictionary = _make()
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var npc: NpcSpawn = mode.get_map().npc_spawns()[0]
	var at: Vector2 = npc.ground_position(mode.get_map())
	mode.set_leader_position(at + Vector2(0.0, 1.0))
	mode.set_leader_facing(Vector2.UP)
	view.get_camera().snap_to(at)
	view._process(_DT)
	var label: Label = view.get_interact_label()
	var screen: Vector2 = view.get_camera().unproject_position(OverworldView.ground_to_world(at))
	assert_bool(label.visible).is_true()
	# Centred on the target, and above its feet on screen.
	# 2 px: the headless viewport is small, and a label settles its size a
	# frame after its text changes.
	assert_float(label.position.x + label.size.x * 0.5).is_equal_approx(screen.x, 2.0)
	assert_float(label.position.y + label.size.y).is_less(screen.y)


func test_prompt_hidden_under_overlays_transitions_and_redirects() -> void:
	var ctx: Dictionary = _make()
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var machine: GameStateMachine = ctx["machine"]
	var npc: Vector2 = mode.get_map().npc_spawns()[0].ground_position(mode.get_map())
	mode.set_leader_position(npc + Vector2(0.0, 1.0))
	mode.set_leader_facing(Vector2.UP)
	view._process(_DT)
	assert_bool(view.get_interact_label().visible).is_true()
	# Overlay.
	machine.open_overlay(GameStateMachine.OverlayKind.MENU)
	view._process(_DT)
	assert_bool(view.get_interact_label().visible).is_false()
	machine.close_overlay()
	view._process(_DT)
	assert_bool(view.get_interact_label().visible).is_true()
	# Redirect (a same-instance transition).
	assert_int(mode.redirect_leader(npc + Vector2(0.0, 1.0), Vector2.UP)).is_equal(GameStateMachine.RequestResult.OK)
	view._process(_DT)
	assert_bool(view.get_interact_label().visible).is_false()
	assert_object(view.interact_target).is_null()


func _make() -> Dictionary:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var mode: OverworldMode = (load(_SCENE) as PackedScene).instantiate() as OverworldMode
	mode.setup(machine, MapEntryPayload.new("map_paris_segment_placeholder", &"from_town"))
	(env["loader"] as StubSceneLoader).current_mode_node_value = mode
	add_child(mode)
	auto_free(mode)
	mode.set_process(false)
	var view: OverworldView = mode.get_node(^"OverworldView") as OverworldView
	view.set_process(false)
	return {"machine": machine, "mode": mode, "view": view}
