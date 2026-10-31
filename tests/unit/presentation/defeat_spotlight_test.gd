## Story 053 (GDD sprite-camera-presentation AC-49; ADR-0005 §3): on Defeat
## with party rows of 1, 2, 3 and 4 members, the spotlight's ground-plane
## centre equals the party row's formation centre within 1e-4 m, and every
## party actor's key and rim strengths equal their Battle values.
extends GdUnitTestSuite

const SCENE: String = "res://src/battle/battle_mode.tscn"
const PROFILES_DIR: String = "res://data/presentation/profiles"
const STAGE_PATH: String = "res://data/presentation/stages/battle_default.tres"
const TOL: float = 1e-4


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _resolve(id: StringName) -> LightingProfile:
	return load(PROFILES_DIR.path_join("%s.tres" % id)) as LightingProfile


func _party(n: int) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for i: int in n:
		out.append(Combatant.new("Hero %d" % i, 30, 10, 12, 8, 10, false))
	return out


func _expected_centre(n: int) -> Vector3:
	var stage: BattleStage = load(STAGE_PATH) as BattleStage
	var sum := Vector3.ZERO
	for i: int in n:
		sum += stage.slot_anchor(i)
	return Vector3(sum.x / n, 0.0, sum.z / n)


func _defeated_mode(n: int) -> BattleMode:
	var mode: BattleMode = (load(SCENE) as PackedScene).instantiate() as BattleMode
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "defeat_spotlight_fight"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = _party(n)
	mode.setup(null, payload)
	add_child(mode)
	auto_free(mode)
	mode.set_process(false)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.set_process(false)
	# Stands in for the Director's mode_entered (bind + Battle entry light).
	stage.bind_profiles(_resolve)
	stage.apply_profile(_resolve(&"battle"), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	mode.settle_replay()
	DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.DEFEAT)
	assert_int(mode.battle.state).is_equal(BattleCore.State.LOST)
	mode.settle_replay()
	return mode


func test_formation_centre_is_mean_ground_position() -> void:
	var anchors: Array[Vector3] = [Vector3(-1.0, 0.0, -9.0), Vector3(2.0, 0.0, -10.0)]
	var c: Vector3 = DefeatSpotlight.formation_centre(anchors)
	assert_vector(c).is_equal_approx(Vector3(0.5, 0.0, -9.5), Vector3(TOL, TOL, TOL))
	assert_vector(DefeatSpotlight.formation_centre([] as Array[Vector3])).is_equal(Vector3.ZERO)


func test_spotlight_centres_on_party_row_for_one_to_four_members() -> void:
	for n: int in [1, 2, 3, 4]:
		var mode: BattleMode = _defeated_mode(n)
		var spot: DefeatSpotlight = mode.defeat_spotlight()
		assert_object(spot).override_failure_message("no spotlight for a row of %d" % n).is_not_null()
		var got: Vector3 = spot.ground_centre()
		var want: Vector3 = _expected_centre(n)
		assert_float(got.distance_to(want)).override_failure_message(
				"row of %d: spotlight at %s, formation centre %s" % [n, got, want]).is_less_equal(TOL)
		assert_float(spot.progress()).is_equal(1.0)
		assert_bool(spot.visible).is_true()


func test_party_key_and_rim_equal_battle_values_on_defeat() -> void:
	var battle: LightingProfile = _resolve(&"battle")
	for n: int in [1, 2, 3, 4]:
		var mode: BattleMode = _defeated_mode(n)
		var stage: DioramaStage = mode.get_node(^"%DioramaStage")
		assert_bool(stage.is_blending()).override_failure_message("Defeat blend unfinished").is_false()
		assert_float(stage.key_light.light_energy).is_equal_approx(battle.key_energy, TOL)
		assert_float(stage.current_rim_strength).is_equal_approx(battle.rim_strength, TOL)
		# The spotlight never lights an actor.
		assert_int(mode.defeat_spotlight().light_cull_mask & DioramaStage.LAYER_ACTORS).is_equal(0)


func test_spotlight_off_before_defeat() -> void:
	var mode: BattleMode = (load(SCENE) as PackedScene).instantiate() as BattleMode
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "defeat_spotlight_fight"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = _party(2)
	mode.setup(null, payload)
	add_child(mode)
	auto_free(mode)
	mode.set_process(false)
	var spot: DefeatSpotlight = mode.defeat_spotlight()
	assert_bool(spot == null or not spot.visible).is_true()
