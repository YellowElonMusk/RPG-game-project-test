## Headless audio smoke check (systems index #20): every id in
## data/config/audio_events.tres resolves to a file that loads as an
## AudioStream, and the overworld's code-fired ids are all listed. Prints one
## line per id (path chosen, length) and a summary; exits 1 on a failure.
##
## Run: godot --headless --path . -s res://tools/audio/audio_smoke.gd
extends SceneTree


func _init() -> void:
	var table: AudioEventTable = AudioEventTable.load_default()
	var failures: int = 0
	var count: int = 0
	for kind: int in [AudioEventTable.Kind.MUSIC, AudioEventTable.Kind.AMBIENCE, AudioEventTable.Kind.SFX]:
		var col: Dictionary = table.column(kind)
		for id: String in col:
			count += 1
			var path: String = table.resolve(kind, StringName(id), func(p: String) -> bool: return ResourceLoader.exists(p))
			var stream: AudioStream = null if path.is_empty() else ResourceLoader.load(path) as AudioStream
			if stream == null:
				failures += 1
				print("FAIL %s %s: no loadable file" % [AudioEventTable.Kind.keys()[kind], id])
				continue
			print("ok   %-8s %-26s %5.2fs  %s" % [AudioEventTable.Kind.keys()[kind], id, stream.get_length(),
					path.get_file()])
	for id: StringName in OverworldSfx.ALL:
		if not table.has_id(AudioEventTable.Kind.SFX, id):
			failures += 1
			print("FAIL overworld sfx '%s' unlisted" % id)
	print("audio_smoke: %d ids, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)
