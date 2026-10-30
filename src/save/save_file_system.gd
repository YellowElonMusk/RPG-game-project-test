## File access for saves (ADR-0009 §9): `ensure_dirs`, a bounded
## `read_text`, a `write_text` that checks every store, `rename`, `remove`
## and `exists`. Production uses this class on `user://`; tests subclass it
## with an in-memory fake that can fail at any step, so the atomic-write,
## hashing and corruption rules are tested without touching disk. Nothing
## read here is ever passed to `ResourceLoader`, `load()` or `str_to_var()`.
class_name SaveFileSystem
extends RefCounted


## Creates `dir` (once, at boot).
func ensure_dirs(dir: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(dir) == OK


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## The file's raw text, or null when it is missing or larger than
## `max_bytes` (refused before reading, ADR-0009 §1 "Input bounds").
func read_text(path: String, max_bytes: int) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() > max_bytes:
		f.close()
		return null
	var text: String = f.get_as_text()
	f.close()
	return text


## Writes `text`; false if the open or the store fails.
func write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var ok: bool = f.store_string(text)
	f.close()
	return ok


## Renames `from` to `to`, replacing `to`.
func rename(from: String, to: String) -> bool:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	return DirAccess.rename_absolute(from, to) == OK


func remove(path: String) -> bool:
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(path) == OK
