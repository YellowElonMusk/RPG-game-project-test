## The world-shader `TIME` lint (ADR-0005 §7; GDD AC-47, story 051): a world
## shader in a mode scene must read `mode_time`, never `TIME`, so the Menu's
## freeze stops it. Checks shader files, shader code embedded in scenes and
## resources, and visual shaders' Time input nodes, but only for files under a
## mode-scene path -- a UI shader outside `ModeHost` may read `TIME`.
##
## Static and text-based: files are read as text, never loaded or compiled.
## Emits one finding per offending file (an observation list; the caller decides).
class_name WorldShaderTimeLint
extends RefCounted

## Where the game's mode scenes are listed (`TransitionConfig.mode_scene_paths`).
const TRANSITION_CONFIG_PATH := "res://data/config/transition_config.tres"
## File extensions the lint reads.
const LINTED_EXTENSIONS: Array[String] = ["gdshader", "gdshaderinc", "tscn", "tres"]


## The directories whose shader-bearing files are world content for mode
## scenes even when no mode scene references them yet (stages, set kits,
## sprite sets, the actor shader).
static func default_mode_roots() -> PackedStringArray:
	return PackedStringArray([
		"res://src/battle", "res://src/overworld", "res://src/game_state/modes",
		"res://src/presentation", "res://data/presentation"])


## Whether shader `code` reads the `TIME` built-in: a whole-word `TIME` outside
## `//` and `/* */` comments.
static func code_reads_time(code: String) -> bool:
	var regex := RegEx.create_from_string(r"\bTIME\b")
	return regex.search(strip_comments(code)) != null


## `code` with `//` line comments and `/* */` block comments removed.
static func strip_comments(code: String) -> String:
	var block := RegEx.create_from_string(r"(?s)/\*.*?\*/")
	var line := RegEx.create_from_string(r"//[^\n]*")
	return line.sub(block.sub(code, " ", true), "", true)


## The finding for one file, or "" if it is clean: a shader file reading
## `TIME`, a scene/resource whose embedded `code = "..."` reads it, or a
## visual shader with a Time input node.
static func file_violation(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	match path.get_extension():
		"gdshader", "gdshaderinc":
			if code_reads_time(text):
				return "%s: world shader reads TIME (use mode_time)" % path
		"tscn", "tres":
			var embedded := RegEx.create_from_string(r'code = "((?:[^"\\]|\\.)*)"')
			for found: RegExMatch in embedded.search_all(text):
				if code_reads_time(found.get_string(1).c_unescape()):
					return "%s: embedded shader code reads TIME (use mode_time)" % path
			var time_node := RegEx.create_from_string(r'input_name\s*=\s*"time"')
			if text.contains("VisualShaderNodeInput") and time_node.search(text) != null:
				return "%s: visual shader has a Time input node (use mode_time)" % path
	return ""


## Whether `path` is under one of `roots` (a directory prefix or the file itself).
static func is_under(path: String, roots: PackedStringArray) -> bool:
	for root: String in roots:
		if path == root or path.begins_with(root.trim_suffix("/") + "/"):
			return true
	return false


## The findings for every file in `paths` that sits under `mode_roots`.
static func lint(paths: PackedStringArray, mode_roots: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	for path: String in paths:
		if not is_under(path, mode_roots):
			continue
		var finding: String = file_violation(path)
		if not finding.is_empty():
			errors.append(finding)
	return errors


## Every lintable file under directory `root`, recursively (sorted).
static func collect_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(root):
		if LINTED_EXTENSIONS.has(file_name.get_extension()):
			out.append(root.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(root):
		out.append_array(collect_files(root.path_join(dir_name)))
	out.sort()
	return out


## The shipped project's mode-scene files: every mode scene in the transition
## config plus its lintable dependencies (recursively), and every lintable file
## under `default_mode_roots()`.
static func project_mode_files() -> PackedStringArray:
	var seen: Dictionary = {}
	for root: String in default_mode_roots():
		if DirAccess.dir_exists_absolute(root):
			for path: String in collect_files(root):
				seen[path] = true
	var config: Resource = ResourceLoader.load(TRANSITION_CONFIG_PATH)
	if config != null:
		var scenes: Dictionary = config.get("mode_scene_paths")
		for scene: Variant in scenes.values():
			_add_with_dependencies(String(scene), seen)
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## Lints `project_mode_files()`; every file there is under a mode-scene path.
static func lint_project() -> PackedStringArray:
	var files: PackedStringArray = project_mode_files()
	return lint(files, files)


static func _add_with_dependencies(path: String, seen: Dictionary) -> void:
	if path.is_empty() or seen.has(path) or not LINTED_EXTENSIONS.has(path.get_extension()):
		return
	if not FileAccess.file_exists(path):
		return
	seen[path] = true
	for dep: String in ResourceLoader.get_dependencies(path):
		# Entries are "uid::type::path" (or a bare path).
		var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		_add_with_dependencies(dep_path, seen)
