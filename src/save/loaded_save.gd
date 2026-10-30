## A slot read and verified (`SaveService.read_slot`), then staged
## (`SaveService.preflight`). It is also the payload of Title's Continue
## transition: the loader's save commit applies it in SWAP (ADR-0009 §6).
class_name LoadedSave
extends RefCounted

## `SaveService.LoadStatus`.
var status: int = 1  # EMPTY
var slot: int = 0
## True when the main file was missing or damaged and the `.bak` was read.
var from_backup: bool = false
## key -> migrated section data.
var sections: Dictionary = {}
## key -> SaveStage, after preflight.
var stages: Dictionary = {}
## Sections no participant owns, kept verbatim and written back.
var unknown_sections: Dictionary = {}
var summary: Dictionary = {}
var playtime_s: float = 0.0
## Load report: dropped fields, stage errors.
var report: PackedStringArray = PackedStringArray()


func is_ok() -> bool:
	return status == 0  # SaveService.LoadStatus.OK
