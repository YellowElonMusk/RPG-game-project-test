## Writes the Audio Manager's PLACEHOLDER sounds (systems index #20) into
## res://assets/audio/placeholder/: quiet synth blips for the SFX, short
## chord loops per context and filtered-noise ambience beds. Deterministic
## (fixed seed). Real assets replace them by being listed first in
## data/config/audio_events.tres; nothing here is final audio.
##
## Run: godot --headless --path . -s res://tools/audio/gen_placeholder_audio.gd
## then: godot --headless --path . --import
extends SceneTree

const RATE: int = 22050
const OUT_DIR: String = "res://assets/audio/placeholder/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261104
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_sfx()
	_music()
	_ambience()
	print("gen_placeholder_audio: done")
	quit()


# -- SFX ----------------------------------------------------------------------

func _sfx() -> void:
	_write("ph_ui_move", _tone(1250.0, 0.035, 0.10, "sine", 0.002))
	_write("ph_ui_confirm", _cat([_tone(880.0, 0.04, 0.12, "tri"), _tone(1320.0, 0.06, 0.12, "tri")]))
	_write("ph_ui_cancel", _cat([_tone(523.0, 0.04, 0.11, "tri"), _tone(392.0, 0.06, 0.11, "tri")]))
	_write("ph_ui_refused", _tone(196.0, 0.05, 0.08, "sine", 0.002))
	_write("ph_ui_text_blip", _tone(740.0, 0.025, 0.05, "square", 0.001))
	_write("ph_ui_save", _cat([_tone(523.0, 0.08, 0.12, "tri"), _tone(659.0, 0.08, 0.12, "tri"),
			_tone(784.0, 0.16, 0.12, "tri")]))
	_write("ph_ui_buy", _cat([_tone(988.0, 0.06, 0.12, "square"), _tone(1319.0, 0.18, 0.12, "square")]))
	_write("ph_bt_encounter_start", _mix_all([_sweep(220.0, 990.0, 0.28, 0.18), _noise(0.28, 0.10, 0.35)]))
	_write("ph_bt_hit", _mix_all([_noise(0.09, 0.30, 0.5), _sweep(160.0, 60.0, 0.10, 0.35)]))
	_write("ph_bt_hit_heavy", _mix_all([_noise(0.16, 0.34, 0.35), _sweep(120.0, 40.0, 0.20, 0.45)]))
	_write("ph_bt_crit", _mix_all([_noise(0.12, 0.32, 0.6), _sweep(900.0, 300.0, 0.14, 0.2)]))
	_write("ph_bt_heal", _cat([_tone(784.0, 0.07, 0.10, "sine"), _tone(988.0, 0.07, 0.10, "sine"),
			_tone(1175.0, 0.07, 0.10, "sine"), _tone(1568.0, 0.20, 0.10, "sine")]))
	_write("ph_bt_ko_squad", _sweep(330.0, 110.0, 0.35, 0.22, "tri"))
	_write("ph_bt_ko_enemy", _mix_all([_sweep(440.0, 90.0, 0.30, 0.22, "square"), _noise(0.12, 0.12, 0.4)]))
	_write("ph_bt_flee", _mix_all([_sweep(700.0, 120.0, 0.45, 0.14, "tri"), _noise(0.45, 0.06, 0.2)]))
	_write("ph_ow_notice", _cat([_tone(1568.0, 0.05, 0.10, "sine"), _silence(0.03), _tone(1568.0, 0.08, 0.10, "sine")]))
	_write("ph_ow_chase", _cat([_noise(0.03, 0.10, 0.6), _silence(0.07), _noise(0.03, 0.10, 0.6)]))
	_write("ph_ow_stun", _wobble(600.0, 0.4, 0.10))
	_write("ph_ow_liberation", _mix_all([_noise(0.5, 0.10, 0.3), _chord([392.0, 494.0, 587.0], 0.9, 0.08)]))
	_write("ph_ow_liberation_off", _noise(0.22, 0.12, 0.4))
	_write("ph_ow_checkpoint_denied", _sweep(110.0, 50.0, 0.18, 0.4))
	# Stings (Music bus, one-shot).
	_write("ph_stg_victory", _cat([_chord([523.0, 659.0, 784.0], 0.15, 0.10), _chord([523.0, 659.0, 784.0], 0.15, 0.10),
			_chord([698.0, 880.0, 1047.0], 0.6, 0.11)]))
	_write("ph_stg_victory_boss", _cat([_chord([392.0, 494.0, 587.0], 0.2, 0.10), _chord([523.0, 659.0, 784.0], 0.2, 0.10),
			_chord([587.0, 740.0, 880.0], 0.2, 0.10), _chord([784.0, 988.0, 1175.0], 1.0, 0.12)]))
	_write("ph_stg_defeat", _cat([_tone(392.0, 0.3, 0.10, "tri"), _tone(370.0, 0.3, 0.10, "tri"),
			_tone(349.0, 0.3, 0.10, "tri"), _tone(330.0, 0.8, 0.10, "tri")]))
	_write("ph_stg_level_up", _cat([_tone(1047.0, 0.08, 0.09, "sine"), _tone(1319.0, 0.08, 0.09, "sine"),
			_tone(1568.0, 0.08, 0.09, "sine"), _tone(2093.0, 0.3, 0.09, "sine")]))


# -- Music loops ----------------------------------------------------------------

## Chords as semitone offsets from the key's root (C4 = 60).
func _music() -> void:
	# name, root midi, bpm, chords (root offset, minor?), lead wave
	_write("ph_mus_title", _loop(60, 112, [[0, false], [7, false], [9, true], [5, false]], "square"))
	_write("ph_mus_bureaucratia", _loop(65, 100, [[0, false], [5, false], [7, false], [0, false]], "tri"))
	_write("ph_mus_megacorp", _loop(57, 104, [[0, true], [8, false], [3, false], [10, false]], "square"))
	_write("ph_mus_influencia", _loop(62, 116, [[0, false], [9, true], [5, false], [7, false]], "tri"))
	_write("ph_mus_liberty7", _loop(58, 120, [[0, false], [5, false], [0, false], [7, false]], "square"))
	_write("ph_mus_liberated", _loop(67, 104, [[0, false], [4, true], [5, false], [7, false]], "tri"))
	_write("ph_mus_dungeon", _loop(62, 84, [[0, true], [5, true], [0, true], [7, false]], "tri", true))
	_write("ph_mus_boss_chamber", _drone(50, 70))
	_write("ph_mus_camp", _loop(58, 76, [[0, false], [9, true], [2, true], [7, false]], "sine", true))
	_write("ph_mus_credits", _loop(65, 96, [[0, false], [7, false], [9, true], [5, false]], "sine"))
	_write("ph_bx_floor_pulse", _floor_pulse(92))


func _loop(root: int, bpm: float, chords: Array, lead: String, sparse: bool = false) -> PackedFloat32Array:
	var beat: float = 60.0 / bpm
	var total: float = beat * 4.0 * chords.size()
	var out := _silence(total)
	for bar: int in chords.size():
		var c: Array = chords[bar]
		var r: int = root + int(c[0])
		var third: int = 3 if bool(c[1]) else 4
		var notes: Array[int] = [r, r + third, r + 7]
		var t0: float = bar * 4.0 * beat
		# Pad: soft triangle triad for the bar.
		_mix(out, _chord(_hz_all(notes, -12), beat * 4.0 - 0.02, 0.035, 0.08), t0)
		# Bass: root on beats 1 and 3.
		for b: int in [0, 2]:
			_mix(out, _tone(_hz(r - 24), beat * 1.6, 0.10, "sine", 0.005), t0 + b * beat)
		# Pluck arpeggio on the 8ths (quarters when sparse).
		var steps: int = 4 if sparse else 8
		var step_s: float = beat * 4.0 / steps
		var pattern: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]
		for s: int in steps:
			var n: int = notes[pattern[s % pattern.size()]]
			_mix(out, _tone(_hz(n), step_s * 0.9, 0.045, lead, 0.003), t0 + s * step_s)
	return out


func _drone(root: int, bpm: float) -> PackedFloat32Array:
	var beat: float = 60.0 / bpm
	var total: float = beat * 16.0
	var out := _silence(total)
	_mix(out, _chord([_hz(root - 12), _hz(root - 5)], total - 0.05, 0.05, 0.6), 0.0)
	for b: int in 16:
		_mix(out, _noise(0.02, 0.04, 0.7), b * beat)
		if b % 4 == 0:
			_mix(out, _sweep(90.0, 45.0, 0.2, 0.12), b * beat)
	return out


## Kick-only beat: a mouth-ish thump on each beat, 4 beats.
func _floor_pulse(bpm: float) -> PackedFloat32Array:
	var beat: float = 60.0 / bpm
	var out := _silence(beat * 8.0)
	for b: int in 8:
		_mix(out, _sweep(130.0, 45.0, 0.16, 0.22), b * beat)
	return out


# -- Ambience -------------------------------------------------------------------

func _ambience() -> void:
	_write("ph_amb_street", _bed(0.035, 0.12, 0.0, 0.0))
	_write("ph_amb_harbour", _bed(0.04, 0.06, 0.0, 0.15))
	_write("ph_amb_office", _bed(0.02, 0.2, 120.0, 0.0))
	_write("ph_amb_cafe", _bed(0.025, 0.15, 0.0, 0.0, true))


## A seamless 8 s bed: low-passed noise (`alpha` smaller = darker), an
## optional hum and an optional slow swell, the tail crossfaded into the head.
func _bed(amp: float, alpha: float, hum_hz: float, swell: float, clinks: bool = false) -> PackedFloat32Array:
	var dur: float = 8.0
	var fade: int = int(RATE * 0.5)
	var raw := _noise(dur + 0.5, amp, alpha, false)
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var v: float = raw[i]
		if i < fade:
			var k: float = float(i) / fade
			v = raw[i] * k + raw[n + i] * (1.0 - k)
		var t: float = float(i) / RATE
		if hum_hz > 0.0:
			v += sin(TAU * hum_hz * t) * amp * 0.5
		if swell > 0.0:
			v *= 1.0 + swell * sin(TAU * t / dur)
		out[i] = v
	if clinks:
		for k: int in 3:
			_mix(out, _tone(2637.0, 0.12, 0.02, "sine", 0.001), 1.3 + k * 2.4)
	return out


# -- Synth helpers ------------------------------------------------------------

func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _hz_all(notes: Array[int], shift: int) -> Array[float]:
	var out: Array[float] = []
	for n: int in notes:
		out.append(_hz(n + shift))
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * dur))
	return out


func _osc(wave: String, phase: float) -> float:
	match wave:
		"square":
			return 0.6 if fmod(phase, 1.0) < 0.5 else -0.6
		"tri":
			return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
	return sin(TAU * phase)


## One note with a short attack and an exponential-ish decay.
func _tone(freq: float, dur: float, amp: float, wave: String = "sine", attack: float = 0.005) -> PackedFloat32Array:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var env: float = minf(1.0, t / maxf(attack, 0.0005)) * pow(1.0 - float(i) / n, 2.0)
		out[i] = _osc(wave, freq * t) * amp * env
	return out


func _sweep(f0: float, f1: float, dur: float, amp: float, wave: String = "sine") -> PackedFloat32Array:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		out[i] = _osc(wave, phase) * amp * minf(1.0, i / (RATE * 0.003)) * pow(1.0 - k, 1.5)
	return out


func _wobble(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		phase += (freq + 80.0 * sin(TAU * 9.0 * t)) / RATE
		out[i] = sin(TAU * phase) * amp * (1.0 - float(i) / n)
	return out


## Low-passed white noise (`alpha` 0..1, smaller = darker), decaying unless
## `decay` is false.
func _noise(dur: float, amp: float, alpha: float, decay: bool = true) -> PackedFloat32Array:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var y: float = 0.0
	for i: int in n:
		y += alpha * (_rng.randf_range(-1.0, 1.0) - y)
		var env: float = pow(1.0 - float(i) / n, 2.0) if decay else 1.0
		out[i] = y * amp * env * (1.0 / maxf(sqrt(alpha), 0.2))
	return out


func _chord(freqs: Array, dur: float, amp: float, attack: float = 0.01) -> PackedFloat32Array:
	var out := _silence(dur)
	for f: float in freqs:
		_mix(out, _tone(f, dur, amp, "tri", attack), 0.0)
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


func _mix_all(parts: Array) -> PackedFloat32Array:
	var longest: int = 0
	for p: PackedFloat32Array in parts:
		longest = maxi(longest, p.size())
	var out := PackedFloat32Array()
	out.resize(longest)
	for p: PackedFloat32Array in parts:
		_mix(out, p, 0.0)
	return out


## Adds `src` into `into` at `at_s`, wrapping past the end (so loops stay seamless).
func _mix(into: PackedFloat32Array, src: PackedFloat32Array, at_s: float) -> void:
	var start: int = int(at_s * RATE)
	var size: int = into.size()
	for i: int in src.size():
		var j: int = (start + i) % size
		into[j] += src[i]


func _write(name: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(OUT_DIR + name + ".wav", FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
