## In-memory `SaveFileSystem` (ADR-0009 §9): files are a path -> text map,
## and any step can be made to fail, so the atomic-write and corruption
## rules are tested without touching disk.
class_name MemorySaveFileSystem
extends SaveFileSystem

var files: Dictionary = {}
var fail_write: bool = false
var fail_rename: bool = false
## When set, `read_text` of a `.tmp.json` returns this instead (verify step).
var corrupt_readback: String = ""


func ensure_dirs(_dir: String) -> bool:
	return true


func exists(path: String) -> bool:
	return files.has(path)


func read_text(path: String, max_bytes: int) -> Variant:
	if not files.has(path):
		return null
	if not corrupt_readback.is_empty() and path.ends_with(".tmp.json"):
		return corrupt_readback
	var text: String = files[path]
	if text.to_utf8_buffer().size() > max_bytes:
		return null
	return text


func write_text(path: String, text: String) -> bool:
	if fail_write:
		return false
	files[path] = text
	return true


func rename(from: String, to: String) -> bool:
	if fail_rename or not files.has(from):
		return false
	files[to] = files[from]
	files.erase(from)
	return true


func remove(path: String) -> bool:
	files.erase(path)
	return true
