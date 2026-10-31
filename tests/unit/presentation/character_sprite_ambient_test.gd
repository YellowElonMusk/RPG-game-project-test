## Story 011, AC-9 (ADR-0005 §1/§4; GDD rule 7): with Dialogue or the Defeat
## Prompt open, mode time keeps advancing and so does a sprite's ambient
## (idle/walk) animation, stepped by `CharacterSprite.step_ambient(mode_dt)`
## with the machine's own `mode_time` deltas. The Menu, by contrast, stops
## mode time and the frame holds. Drives a real `GameStateMachine` over the
## stub loader; expected frames come from an independent `floor(t * fps)`.
extends GdUnitTestSuite

const _DT := 1.0 / 60.0
const _FPS := 8.0
const _FRAME_COUNT := 4
## Ticks run with an overlay open (1.5 s: several full idle loops).
const _TICKS := 90


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _sprite() -> CharacterSprite:
	var sprite: CharacterSprite = auto_free(CharacterSprite.new())
	add_child(sprite)
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	sprite.card_camera = camera
	var frames := SpriteFrames.new()
	var tex: Texture2D = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	frames.add_animation(&"idle_front")
	frames.set_animation_speed(&"idle_front", _FPS)
	frames.set_animation_loop(&"idle_front", true)
	for i: int in _FRAME_COUNT:
		frames.add_frame(&"idle_front", tex)
	sprite.setup(frames, PresentationConfig.new())
	sprite.show_frame(&"idle", &"front", false, false, 0)
	return sprite


func _expected_frame(t: float) -> int:
	return int(floorf(t * _FPS + 1e-6)) % _FRAME_COUNT


## Ticks the machine once and steps the sprite by the mode-time delta.
func _tick(machine: GameStateMachine, sprite: CharacterSprite) -> void:
	var before: float = machine.mode_time
	machine.tick(_DT)
	sprite.step_ambient(machine.mode_time - before)


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1


func _assert_advances(machine: GameStateMachine, sprite: CharacterSprite) -> void:
	var seen: Dictionary = {}
	var t: float = 0.0
	for i: int in _TICKS:
		var mode_before: float = machine.mode_time
		_tick(machine, sprite)
		assert_float(machine.mode_time - mode_before).is_equal_approx(_DT, 1e-9)
		t += _DT
		assert_int(sprite.frame).override_failure_message("tick %d" % i) \
				.is_equal(_expected_frame(t))
		seen[sprite.frame] = true
	assert_int(seen.size()).is_equal(_FRAME_COUNT)


func test_ambient_animation_advances_while_dialogue_is_open() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = GameStateFixtures.track(env["machine"])
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_assert_advances(machine, _sprite())


func test_ambient_animation_advances_while_the_defeat_prompt_is_open() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = GameStateFixtures.track(env["machine"])
	var loader: StubSceneLoader = env["loader"]
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = RefCounted.new()
	loader.current_mode_node_value = battle_stub
	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	_run_to_idle(machine)
	assert_int(machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	_assert_advances(machine, _sprite())


## The contrast case: the Menu stops mode time, so the frame holds exactly,
## and stepping resumes from where it stopped once the Menu closes.
func test_menu_holds_the_frame_and_closing_it_resumes() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = GameStateFixtures.track(env["machine"])
	var sprite := _sprite()
	for i: int in 10:
		_tick(machine, sprite)
	var held: int = sprite.frame
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.MENU, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	for i: int in 60:
		_tick(machine, sprite)
		assert_int(sprite.frame).is_equal(held)
	machine.close_overlay()
	for i: int in 30:
		_tick(machine, sprite)
	assert_int(sprite.frame).is_equal(_expected_frame(40.0 * _DT))


## Beat-driven animations are never stepped by ambient time.
func test_step_ambient_leaves_a_beat_driven_animation_alone() -> void:
	var sprite := _sprite()
	sprite.sprite_frames.add_animation(&"attack_front")
	for i: int in 3:
		sprite.sprite_frames.add_frame(&"attack_front", sprite.sprite_frames.get_frame_texture(&"idle_front", 0))
	sprite.show_frame(&"attack", &"front", false, false, 1)
	for i: int in 30:
		sprite.step_ambient(_DT)
	assert_int(sprite.frame).is_equal(1)
