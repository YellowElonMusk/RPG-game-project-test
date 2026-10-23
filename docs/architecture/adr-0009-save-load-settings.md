# ADR-0009: Save/Load & Settings — Hashed JSON Saves, Registered Participants, One Settings Service

## Status
Accepted

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR). Revision 2 folds in both reviews (see Review History).

## Summary
Three Accepted ADRs and two GDDs defer persistence to a Save/Load & Settings system that has no design yet. What they defer:
- player binding overrides (TR-input-001);
- the six comfort settings, applied live (TR-presentation-022);
- the UI's text scale and Reduce Blur;
- Title's Continue;
- Game State's safe save moments.

The systems-index lists the system as Vertical Slice and Not Started, with no GDD. The file format, the ownership of each section and the safety rules have to be fixed before any system starts writing its own files.

Decided: two separate stores under `user://`.
- **Saves** are hashed JSON files in numbered slots, written atomically. Each holds one section per registered `SaveParticipant`. A save is decoded and validated in a side-effect-free preflight before any transition starts, and committed during the SWAP phase. Each system owns its section's schema and migrations, and stores catalog IDs, never definitions.
- **Settings** are one JSON file owned by a `SettingsService`. Its narrow per-consumer views are built in the composition root, so Core never imports a Presentation interface.

Nothing from `user://` is ever loaded as a `Resource` or decoded by Godot's variant parser.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (file I/O, serialization) |
| **Layer** | Core |
| **Knowledge Risk** | LOW–MEDIUM. `FileAccess`, `DirAccess` and `JSON` predate the cutoff. 4.4 changed `FileAccess.store_*` to return `bool`. Rename semantics were probed |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (the 4.4 `FileAccess.store_*` row), `deprecated-apis.md`, `current-best-practices.md`. No file-I/O module reference exists |
| **Post-Cutoff APIs Used** | `FileAccess.store_string()` returning `bool` (4.4). Nothing else post-cutoff |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist and TD, 2026-10-22):**<br>(1) `DirAccess.rename_absolute(tmp, target)` replaces an existing target on Windows and accepts `user://` paths. **PROBED.** On Linux it wraps POSIX `rename()`, which replaces atomically. **REASONED**; must be probed on the Steam Deck export;<br>(2) `JSON.parse_string()` returns every number as `float`. 2^53 is exact; 2^53 + 1 is not. **PROBED.** Re-stringifying a parsed object turns `5321` into `5321.0`, so a hash must be computed over the bytes written, never over a re-serialized object (§2). **PROBED by TD**;<br>(3) `JSON.stringify(obj, "", true)` sorts keys at every level, deterministically. **PROBED**;<br>(4) `store_string()` returns `false` on failure, and `get_open_error()` does **not** report a failed store. Only the return value is reliable. **PROBED**;<br>(5) `use_custom_user_dir` + `custom_user_dir_name` gives a path independent of the project name on Windows. **PROBED.** Linux (`~/.local/share/<name>`) is **REASONED**;<br>(6) `String.sha256_text()` is deterministic. **PROBED** in-process; cross-platform is REASONED;<br>(7) `FileAccess.open()` in a missing directory fails with `ERR_FILE_NOT_FOUND`. `user://saves/` is never created automatically. **PROBED**;<br>(8) `str_to_var("Resource(\"res://…\")")` **attempts a resource load even with the default `allow_objects = false`**. **PROBED.** This is why §1 bans the variant parser outright;<br>(9) a `Node` under the root receives `NOTIFICATION_WM_CLOSE_REQUEST`. **PROBED.** That a synchronous flush completes before exit is **REASONED** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data, **Accepted**): stable IDs, `resolve_alias()`, the ID pattern.<br>**ADR-0002** (Game State, **Accepted**): `is_save_safe()`, Title → Overworld, the SWAP phase and rollback, `quit_hook`, `mode_time`.<br>**ADR-0003** (Input System, **Accepted**): `apply_overrides()`, `binding_override_discarded`, `InputBindingsValidator`, the fallback bindings.<br>**ADR-0005** (Sprite & Camera Presentation, **Accepted**): `FlashSettings`.<br>**ADR-0006** (Battle Replay, **Accepted**): `set_speed_settings()`.<br>**ADR-0008** (UI Framework, **Accepted**): the `pre_setup` hook (its ADR-0002 amendment, §2) that assigns `presentation_settings` to the Battle mode (§7); the `UiSettings` interface that this ADR's composition-root adapter implements; `UiContext`, which carries the `InputCapture` facade defined here |
| **Enables** | **The Save/Load & Settings GDD:** slots, triggers and screens can be designed against a fixed contract.<br>**Every Feature system that persists state** (Squad Roster, Leveling & Loyalty, Faction Reputation, Items, Overworld): each registers a participant.<br>**The Vertical Slice remap screen** |
| **Blocks** | Title's Continue, the settings screen, the remap screen, and any story that writes to `user://` |
| **Ordering Note** | **Additive amendment to ADR-0003** (annotation only, §7):<br>- `InputResolver` gains a capture mode;<br>- `InputBindingsValidator` gains a static `validate_bindings(triples)`.<br>**Additive amendment to ADR-0002** (annotation only, §6): the production `SceneLoader` takes an injected `payload_commit: Callable(payload) -> bool`, called during SWAP before the target mode is instantiated. A `false` return is a swap failure. This is the same kind of hook as ADR-0008's `pre_setup`. ADR-0002's `is_save_safe()` is used unchanged.<br>**Depends on ADR-0008** (corrected 2026-10-22, `/architecture-review` 2026-10-22b; earlier revisions said it did not): §7 assigns `presentation_settings` through ADR-0008's `pre_setup` hook, and the `UiSettings` adapter implements ADR-0008's interface. The adapter still lives in the composition root |

## Context

### Problem Statement
Nothing persists today. The MVP has no Continue and no settings screen, and every comfort setting is a default.

The contracts that will read persisted state already exist, though:
- `FlashGate` takes a `FlashSettings` (ADR-0005 §12).
- ADR-0008 defines `UiSettings`.
- ADR-0006 has `set_speed_settings()`.
- The Input resolver has `apply_overrides()` (ADR-0003).
- The Content Data GDD has decided that saves store IDs, and that Save/Load, not the catalog, decides what the player sees for an unknown ID.

Without a decision here, each of those systems would invent its own file, format and timing. The first Feature systems with progress to save (Squad Roster, Leveling, Faction Reputation) are Vertical Slice work, so the format has to be fixed before them.

### Constraints
- **Security.**
  - Godot `Resource` files can embed scripts, so loading one from `user://` runs code from a file the player may have downloaded.
  - Godot's text variant parser follows `Resource("…")` paths even with objects disallowed (probed, item 8).
  - A save must be inert data.
- **Platform.** Windows desktop and a native Linux build on Steam Deck. The Deck can suspend or lose power at any moment, so a write interrupted halfway must not destroy the previous save.
- **Architecture.**
  - No mutable autoloads.
  - The catalog is read-only.
  - Save/Load is Core-layer. It must not import Feature systems or Presentation types (Principle 7).
  - ADR-0003 hands the resolver to exactly two holders.
- **Design gap.** No Save/Load GDD exists. Slot count, save triggers, the Continue policy and how damaged saves are presented are design decisions this ADR must leave open while constraining their shape.

### Requirements
- Persist player binding overrides. Discard an invalid override set with a single notice (input GDD rule 7 and edge cases; TR-input-001).
- Persist the six comfort settings, text scale and Reduce Blur, and apply them live (TR-presentation-022, ADR-0008).
- Save only at Game State's safe save moments: mode Overworld or Camp, no overlay except the Menu, no transition running.
- Saves store IDs and runtime state, never definitions. An unknown ID goes through `resolve_alias()`, and is otherwise handled by the owning system, never guessed.
- A save from an older build loads in a newer one. A save from a newer build is refused with a message.
- A crash or power loss during a write leaves the previous save loadable.
- A bad save never leaves the game half-restored.
- Every rule is testable headlessly with an injected file system.

## Decision

**1. Two stores, both JSON, both under `user://`.**
- **Settings:** `user://settings.json`. One file, machine-wide, never per slot.
- **Saves:** `user://saves/slot_<n>.json`, `n` in `1..SaveConfig.slot_count`.
  - A slot's previous good write is kept as `slot_<n>.bak.json`.
  - `SaveFileSystem.ensure_dirs()` runs `DirAccess.make_dir_recursive_absolute("user://saves")` once at boot (item 7).
- The project sets `application/config/use_custom_user_dir = true` with a fixed `custom_user_dir_name`, so the path doesn't depend on the project name (item 5).

**JSON only.**
- Saves and settings are read with `JSON.parse_string()` and written with `JSON.stringify()`.
- Nothing under `user://` is ever passed to any of these:
  - `ResourceLoader.load()` or `load()`;
  - `str_to_var()` (item 8);
  - `ConfigFile.load()`;
  - `bytes_to_var_with_objects()`;
  - `FileAccess.get_var()`.
- JSON is inert, diffable, and readable in a bug report. Typed readers (§3) handle its loss of the int/float distinction.

**Input bounds.**
- A file larger than `SaveConfig.max_file_bytes` (default 4 MiB) is refused before parsing.
- Top-level types are checked before any field is read.

**2. The save file: a header line that hashes the body bytes.** A slot file is two lines of UTF-8:

```
{"format":"gbtyp_save","version":1,"body_sha256":"<hex>","body_bytes":12345}
{"game_version":"0.3.0","saved_at_unix":1792700000,"playtime_s":5321,"summary":{…},"sections":{"game_state":{"v":1,"data":{…}},…}}
```

- **The body** is `JSON.stringify(envelope, "", true)` computed **once**. `body_sha256` is `sha256_text()` of exactly that string.
- **On load:**
  - split the raw text at the first newline;
  - check the header;
  - hash the second line's raw text and compare it to `body_sha256`;
  - only then parse the body.

  A parsed-and-re-serialized object is never hashed: re-stringifying promotes integers to floats (item 2).
- **`version`** is the file format's version. `sections.<key>.v` is each participant's schema version, migrated independently.
- **`summary`** is merged from participants' `summary_fields()`, so the slot list can show a slot without restoring it.
- **The hash is an integrity check only** (truncation, a torn write, a disk error). It is not tamper protection, and a hand-edited save with a recomputed hash loads normally.
- **A mismatch reads as `CORRUPT`.** How a corrupt slot is presented, and whether the `.bak` is offered, is the Save/Load GDD's call. Provisionally: the slot shows as damaged and the backup is offered.

**3. Participants own their sections.** A system that persists state implements `SaveParticipant` (`src/save/save_participant.gd`, `RefCounted`):

```gdscript
func save_key() -> StringName                                     # stable, snake_case; never renamed
func schema_version() -> int
func capture() -> Dictionary                                      # JSON-safe only
func migrate(data: Dictionary, from_version: int) -> Dictionary   # step-wise to schema_version()
func stage(data: Dictionary, reader: SaveReader) -> SaveStage     # decode + resolve; NO side effects
func commit(staged: SaveStage) -> void                            # apply; must not fail
func reset_to_new_game() -> void                                  # New Game, and before any commit
func summary_fields() -> Dictionary                               # optional
```

- **IDs, not definitions.** A section stores catalog IDs (`char_karen`) and runtime values (current HP, flags), never record contents (Content Data rule 7).
- **`SaveReader`** wraps a section's dictionary with typed getters:
  - `get_int(key, default)` rejects a non-integral float;
  - `get_float`, `get_bool`, `get_string`, `get_array`;
  - `get_vector2` reads `[x, y]`;
  - `get_id(key, record_type)` checks ADR-0001's ID length and pattern, applies `ContentCatalog.resolve_alias()`, and returns `""` if the ID is neither live nor an alias.

  Every failed read is recorded, so the load report can list what was dropped.
- **Unknown IDs.** The owning participant decides in `stage()`:
  - a non-essential reference (an inventory item) is dropped and reported;
  - an essential one (the current map) makes `stage()` return an error.

  Save/Load never invents a record.
- **Registration.** Participants are registered in one composition-root list, `src/boot/save_bootstrap.gd`, like `ContentBootstrap` (ADR-0004).
  - Save/Load imports no Feature system.
  - Adding a participant adds a line there, and the ADR or story that introduces it names that line.
  - A `save_key` collision is a boot error.
- **Game State's section** holds only what the machine owns: `last_camp_id`.
- **The `overworld` section** (ADR-0012) holds the party's map, position and facing, plus the rest of `WorldState`. `WorldState` is the single owner of those values, and is written every frame, so a Menu save is current. A save made at Camp continues at that camp's return point (`last_camp_return`, §6).
- **`playtime_s`** is owned by `SaveService`. `GameRoot._process` feeds it the machine's `mode_time` delta, which stops while the Menu is open (ADR-0002 §5).

**4. When saves happen.**
- `SaveService.save_to_slot(n) -> SaveResult` refuses (`NOT_SAFE_MOMENT`) unless ADR-0002's existing `machine.is_save_safe()` is true. That query is true when the mode is Overworld or Camp, no overlay other than the Menu is open, and no transition is running.
- `has_unsaved_progress() -> bool` (playtime or a participant changed since the last save or load) drives the quit confirmation's wording (game-state GDD).
- **Left to the Save/Load GDD:** manual saves, autosave at camp or both, the slot count, and any reserved autosave slot. The architecture supports all of them (`SaveConfig.slot_count`).

**5. Writes are atomic, synchronous and small.**
1. **Capture** every participant (in registration order) and build the envelope. Stringify the body once, hash it, and build the header.
2. **Write** `slot_<n>.tmp.json` through `SaveFileSystem`. Check every `store_string()` return (item 4), then `close()`.
3. **Verify.** Re-read the temp file's raw text and compare it **byte-for-byte** with the text written. Only an exact match proceeds.
4. **Swap.** Rename the current `slot_<n>.json` to `slot_<n>.bak.json` (replacing the old backup), then rename the temp file to `slot_<n>.json` (item 1).

A failure at any step leaves the previous `slot_<n>.json` or its `.bak` intact, and returns a `SaveResult` naming the step. A crash between the two renames leaves a valid `.bak`, which `read_slot` falls back to when the main file is missing.

The write is synchronous on the main thread. A save is tens of kilobytes, written at a safe moment when no transition or replay runs. A threaded writer can replace `SaveFileSystem` later without changing participants.

**6. Loading: preflight before the transition, commit in SWAP.**
- **Preflight (Title, at request time).**
  - Title's Continue calls `SaveService.read_slot(n)`: it bounds-checks, verifies the hash, checks `format` and `version`, and migrates each section. It then calls `SaveService.preflight(loaded) -> LoadedSave`, which runs every participant's side-effect-free `stage()`.
  - If any essential stage fails, or the status is `CORRUPT`, `TOO_NEW` or `WRONG_FORMAT`, Title shows the load report and **never requests the transition**. Nothing has changed, and there is nothing to roll back.
  - A section whose key has no registered participant is kept verbatim and written back on the next save, so a downgrade-then-upgrade loses nothing.
  - A registered participant with no section stages its new-game defaults.
- **Commit (SWAP).**
  - On a successful preflight, Title calls `machine.request_transition(Mode.OVERWORLD, loaded)`. **Continue always targets the Overworld**: the game-state GDD's transitions table has no Title → Camp row, and a save made at Camp places the squad at that camp's overworld location.
  - *Additive amendment to ADR-0002:* during SWAP, the production `SceneLoader` calls its injected `payload_commit(payload)` before instantiating the target mode. `GameRoot` binds it to `SaveService.commit_if_loaded(payload)`. For a `LoadedSave` payload, that calls `reset_to_new_game()` then `commit(staged)` on every participant, in registration order, and returns `true`.
  - `commit()` must not fail, because everything that could fail was checked in `stage()`. If it returns `false` anyway (a programming error), the loader reports `FAILED`, ADR-0002's rollback returns to Title, and the half-applied state is cleared by calling `reset_to_new_game()` on every participant.
- **New Game.** Title calls `SaveService.reset_all_to_new_game()` before `request_transition(OVERWORLD)`. Quit to Title followed by New Game therefore starts clean.

**7. Settings: one service, views built in the composition root.**
- **The service.** `SettingsService` (`src/save/settings_service.gd`, a `Node` under `GameRoot/Services`) is created first in `GameRoot._ready()`, before `FlashGate`, `PresentationDirector`, `UiService` and the `InputResolver`'s overrides are applied.
  - It doesn't depend on catalog state, so the settings apply on Content Error too: text scale, Reduce Flashing.
  - It loads `user://settings.json`, which has the same header/body format as §2 with `format: "gbtyp_settings"`. It validates every field against `SettingsSchema` (type, range, enum), and replaces any invalid field with its default, logging each one.
  - A missing or unparseable file means all defaults, written back on the first change.
- **Views** are built in `src/boot/settings_views.gd`, in the composition root, never in Core:
  - `UiSettings` adapter (ADR-0008): `text_scale`, `reduce_blur`, `reduce_motion`;
  - `FlashSettings` adapter (ADR-0005): `reduce_flashing`;
  - `PresentationSettings`: `faster_battle_animations`, `speed_up_boss_entrances`, `screen_shake`, `reduce_motion`.

  Each adapter reads `SettingsService.get_value()` and relays its `value_changed(key)` as the view's `changed`. `SettingsService` itself knows no consumer interface.
- **Delivery.**
  - `FlashGate`, `PresentationDirector` and `UiService` get their views through `setup()`.
  - A mode that needs `PresentationSettings` (the Battle mode, for ADR-0006's `set_speed_settings()`) declares `var presentation_settings`. `GameRoot`'s `pre_setup` hook (ADR-0008 §2) assigns it alongside `ui`. The Battle mode calls `set_speed_settings(...)` on entry and on `changed`.
  - `display_fullscreen` and `display_vsync` are applied by a `DisplaySettingsApplier` in the composition root, which calls `DisplayServer` on load and on change.
- **Writes.** `set_value(key, value) -> bool` validates, applies, emits `value_changed(key)`, and debounces a write (`SettingsConfig.write_delay_s`, 0.5 s, real clock). It flushes immediately:
  - from the machine's `quit_hook` (ADR-0002);
  - on `NOTIFICATION_WM_CLOSE_REQUEST`;
  - on `NOTIFICATION_APPLICATION_FOCUS_OUT` (the Steam Deck's suspend path).

  Settings writes use §5's temp-then-rename.
- **Binding overrides.**
  - **Format.** Stored as the same `"action:device:input"` triples as ADR-0003's `InputBindings`. `SettingsSchema` checks only that they are strings; meaning is the Input System's call.
  - **At boot.** `GameRoot` (not the service, so the resolver keeps exactly two holders) calls `resolver.apply_overrides(settings.get_value(&"bindings"))`. It skips this when the resolver is running on ADR-0003's fallback bindings.
  - **On discard.** `GameRoot` connects `binding_override_discarded(reason)` to `settings.clear_bindings()`, which clears the stored overrides, writes the file, and queues **one** notice.
  - **Notice delivery.** Notices are held in `SettingsService.pending_notices()` until the UI drains them on Title (input GDD: a single notice, then a clean next launch).
- **Remap capture.** *Additive amendment to ADR-0003:* `InputResolver.begin_capture(device_kind)` / `end_capture()`, with `signal capture_completed(token: String)` and `signal capture_cancelled()`.
  - While capturing, no action signal fires, so typing `Z` to bind it never also confirms.
  - The press that opened capture is ignored, and a fresh press is required.
  - A timeout (`InputConfig.capture_timeout_s`) or the cancel binding cancels.
  - The remap screen reaches capture only through `UiContext.input_capture` (an `InputCapture` facade owned by `UiService`, the resolver's second holder; ADR-0008 §1), never the resolver.
  - The screen validates the merged set (defaults plus candidate overrides) with the new static `InputBindingsValidator.validate_bindings(triples: PackedStringArray) -> PackedStringArray` before calling `set_value(&"bindings", …)`.

**8. Settings schema (initial).**

| Key | Values |
|---|---|
| `display_fullscreen` | bool |
| `display_vsync` | bool |
| `text_scale` | 1.0 / 1.25 / 1.5 |
| `faster_battle_animations` | bool |
| `speed_up_boss_entrances` | bool |
| `screen_shake` | `full` / `reduced` / `off` |
| `reduce_blur` | bool |
| `reduce_flashing` | bool |
| `reduce_motion` | bool |
| `swap_confirm_cancel` | bool (input GDD rule 8) |
| `bindings` | PackedStringArray of override triples |
| `locale` | String; empty = OS locale; owned by the Localization ADR |

Defaults equal the GDDs' defaults. Volumes are added with the Audio Manager ADR.

**9. File access is injected.** `SaveFileSystem` (`RefCounted`) wraps `FileAccess` and `DirAccess` for `ensure_dirs`, `read_text` (bounded), `write_text`, `rename` and `list`. Production uses the real one. Tests use an in-memory fake that can fail at any step, so the atomic-write, hashing and corruption rules are unit-tested without touching disk. Clocks (`saved_at_unix`, the debounce) are injected.

### Architecture Diagram

```
GameRoot._ready()
  SettingsService.load()          (no catalog dependency; works on Content Error)
  settings_views.gd (composition root) ─► UiSettings · FlashSettings · PresentationSettings adapters
       │                                       │            │               │
       ├─► DisplaySettingsApplier              ▼            ▼               ▼
       │                                   UiService    FlashGate    PresentationDirector;
       │                                                             Battle mode via pre_setup
       └─ GameRoot: resolver.apply_overrides(bindings)  ◄─ binding_override_discarded → clear_bindings()

SaveService (Services) ── SaveFileSystem ── user://saves/slot_n.json  (+ .bak, .tmp)
   participants ← src/boot/save_bootstrap.gd   (game_state · overworld · squad_roster · …)

 Title Continue: read_slot(n) ─► preflight (stage() all, no side effects) ─ fail → report, no transition
                                   └ ok → request_transition(OVERWORLD, LoadedSave)
                                            SWAP: SceneLoader.payload_commit(payload)
                                                  → reset_to_new_game() + commit(staged), all participants
 Title New Game: reset_all_to_new_game() → request_transition(OVERWORLD)
 save_to_slot(n): requires machine.is_save_safe() → capture → stringify once → hash → tmp → verify bytes → bak → rename

 Remap screen ─► ui.input_capture (UiService) ─► resolver.begin_capture() → capture_completed(token)
              ─► InputBindingsValidator.validate_bindings(merged) ─► SettingsService.set_value(&"bindings")
```

### Key Interfaces

```gdscript
## src/save/save_service.gd — GameRoot/Services; not an autoload
class_name SaveService extends Node
enum SaveResult { OK, NOT_SAFE_MOMENT, CAPTURE_FAILED, WRITE_FAILED, VERIFY_FAILED, RENAME_FAILED }
enum LoadStatus { OK, EMPTY, CORRUPT, TOO_NEW, WRONG_FORMAT, TOO_LARGE, STAGE_FAILED }
func setup(machine: GameStateMachine, catalog: ContentCatalogService, fs: SaveFileSystem,
           config: SaveConfig, participants: Array[SaveParticipant], unix_clock: Callable) -> void
func list_slots() -> Array[SlotSummary]
func save_to_slot(slot: int) -> SaveResult
func read_slot(slot: int) -> LoadedSave            # verified + migrated; no side effects
func preflight(loaded: LoadedSave) -> LoadedSave   # stage() every participant; status STAGE_FAILED on error
func commit_if_loaded(payload: RefCounted) -> bool # bound into SceneLoader.payload_commit
func reset_all_to_new_game() -> void
func add_playtime(delta: float) -> void            # fed from GameRoot with mode_time deltas
func has_unsaved_progress() -> bool

## src/save/save_participant.gd
class_name SaveParticipant extends RefCounted
func save_key() -> StringName
func schema_version() -> int
func capture() -> Dictionary
func migrate(data: Dictionary, from_version: int) -> Dictionary
func stage(data: Dictionary, reader: SaveReader) -> SaveStage   # SaveStage: ok, errors, staged payload
func commit(staged: SaveStage) -> void
func reset_to_new_game() -> void
func summary_fields() -> Dictionary

## src/save/settings_service.gd — GameRoot/Services; knows no consumer interface
class_name SettingsService extends Node
signal value_changed(key: StringName)
func setup(fs: SaveFileSystem, config: SettingsConfig, schema: SettingsSchema, real_clock: Callable) -> void
func get_value(key: StringName) -> Variant
func set_value(key: StringName, value: Variant) -> bool
func clear_bindings() -> void                      # after binding_override_discarded; queues one notice
func pending_notices() -> PackedStringArray        # drained by the UI on Title
func flush() -> void

## Amendments (annotation only)
# ADR-0002: production SceneLoader takes payload_commit: Callable(payload) -> bool, called in SWAP before instantiation
# ADR-0003: InputResolver.begin_capture(device_kind: StringName) / end_capture();
#           signal capture_completed(token: String); signal capture_cancelled()
#           InputBindingsValidator.validate_bindings(triples: PackedStringArray) -> PackedStringArray (static, pure)
```

### Implementation Guidelines
- Nothing under `user://` **may** be passed to `ResourceLoader`, `load()`, `str_to_var()`, `ConfigFile.load()`, `bytes_to_var_with_objects()` or `FileAccess.get_var()`. Saves and settings **must** be JSON.
- A file over `max_file_bytes` **must** be refused before parsing, and top-level types **must** be checked before reading fields.
- The hash **must** cover the exact body bytes written. Code **must never** hash a re-serialized parsed object.
- Every `FileAccess.store_*` result **must** be checked. A failed write **must** leave the previous file and its `.bak` intact.
- `SaveFileSystem.ensure_dirs()` **must** run before the first save.
- A participant's `capture()` **must** return JSON-safe values only (`String`, `int`, `float`, `bool`, `Array`, `Dictionary`). `Vector2` becomes `[x, y]` and `StringName` becomes `String`.
- `stage()` **must** read through `SaveReader` and **must** have no side effects. `commit()` **must not** fail.
- A participant **must** store catalog IDs, never record contents, and **must** resolve them through `SaveReader.get_id()`.
- `save_key` values **are permanent**. A schema change bumps `schema_version()` and adds a `migrate()` step. Old steps are never deleted.
- Only `SaveService` **may** write under `user://saves/`. Only `SettingsService` **may** write `user://settings.json`.
- No consumer **may** hold `SettingsService`; each gets its view adapter. `SettingsService` **must not** import a Presentation or Feature type.
- No code other than `GameRoot` **may** apply binding overrides to the resolver.
- Tests use the in-memory `SaveFileSystem` in `tests/unit/save/`.

## Alternatives Considered

### Alternative 1: Godot resources (`ResourceSaver` / `.tres` in `user://`)
- **Description**: Each participant is a `Resource`, saved with `ResourceSaver.save()` and loaded with `ResourceLoader.load()`.
- **Pros**: Typed fields, no int/float coercion, inspectable in the editor.
- **Cons**:
  - A resource loaded from `user://` can execute an embedded script.
  - Renaming a script class breaks old saves.
- **Rejection Reason**: Security. A save must be inert.

### Alternative 2: `ConfigFile`, `var_to_str` / `str_to_var`, or `store_var`
- **Description**: Godot's own variant serialization, which keeps `Vector2`, `Color` and the int/float distinction.
- **Pros**: Fewer conversions.
- **Cons**: `str_to_var()` follows `Resource("…")` paths even with `allow_objects = false` (probed). `ConfigFile` uses the same parser.
- **Rejection Reason**: Not inert, as probed. JSON is inert by construction.

### Alternative 3: One file for settings and saves
- **Description**: Settings stored inside each save.
- **Pros**: One format, one writer.
- **Cons**: Settings must apply at Title (and on Content Error) before any save is chosen, and must be machine-wide.
- **Rejection Reason**: The GDDs require settings to be live from boot.

### Alternative 4: A central schema owned by Save/Load
- **Description**: Save/Load defines every field of the save.
- **Pros**: The whole format can be read in one place.
- **Cons**: Core would import every Feature system's state.
- **Rejection Reason**: Breaks layering.

### Alternative 5: Restore in the target mode's `setup()`, roll back on failure
- **Description**: The first draft. The mode calls `restore()` and the swap rolls back on error.
- **Pros**: No preflight.
- **Cons**:
  - `setup()` can't report failure.
  - Participants living outside the mode would be left half-restored, and a rollback to Title wouldn't undo them.
- **Rejection Reason**: TD review. A side-effect-free stage before the request, then a commit that can't fail, makes rollback almost never needed.

### Alternative 6: Hash the canonical re-serialization of the parsed body
- **Description**: The first draft's `sha256` field.
- **Pros**: The hash lives inside one JSON object.
- **Cons**: JSON parsing promotes integers to floats, so the recomputed hash never matches (probed).
- **Rejection Reason**: Every valid save would read as corrupt.

## Consequences

### Positive
- No file from `user://` can run code or trigger a resource load.
- A power loss on the Steam Deck mid-save leaves the last good save plus a backup, and a settings change is flushed when the Deck suspends.
- A bad save is caught before the transition, so Continue either works or never starts.
- Each system migrates its own section, so an old save loads in a new build section by section.
- Settings apply live from boot through view adapters in the composition root. Core imports no Presentation type, and the resolver keeps its two holders.
- Remap capture never leaks a `confirm` while a key is being bound.

### Negative
- JSON loses the int/float, `Vector2` and `Color` types. Every participant converts, and reads through `SaveReader`.
- Two additive amendments: ADR-0002's `payload_commit` hook, and ADR-0003's capture mode plus `validate_bindings`.
- Participants implement `stage()`/`commit()` separately, which is more code than a single `restore()`.
- Save/Load can't be fully designed until its GDD exists. This ADR constrains the GDD's choices rather than making them.

## Risks
- **Rename on Linux** (item 1, REASONED). *Mitigation*:
  - a Steam Deck probe runs in the first settings story;
  - `SaveFileSystem.rename` removes the target first if the probe shows a failure;
  - the `.bak` is renamed before that, so a crash still leaves it loadable.
- **JSON number precision** (item 2). *Mitigation*: playtime and unix times fit within 2^53. Large counters are stored as strings.
- **A participant forgets a migration.** *Mitigation*: each participant's tests load a fixture of every past schema version (`tests/unit/save/fixtures/<key>_v<n>.json`).
- **A suspend with no notification at all.** *Mitigation*: the debounce is 0.5 s, and settings changes are rare. Saves are synchronous and complete before control returns.
- **Steam Cloud and Deck sync** are out of scope. The fixed user directory name keeps a future cloud path stable.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-system.md | TR-input-001 (persistence part): player overrides persist via Save/Load | §7 `bindings` setting, applied by `GameRoot` through `apply_overrides()` |
| input-system.md | Edge case: an invalid override is discarded, defaults are restored, one notice, clean next launch | §7 `binding_override_discarded` → `clear_bindings()`, queued notice |
| input-system.md | Rule 8 (VS): remap edits overrides only; confirm/cancel swap; ADR-0003's open text-entry risk | §7 capture mode and `validate_bindings`; §8 `swap_confirm_cancel` |
| sprite-camera-presentation.md | TR-presentation-022: six comfort settings read from the settings service and applied live | §7 views and delivery, §8 schema |
| game-state-scene-flow.md | Safe save moments | §4, ADR-0002's existing `is_save_safe()` |
| game-state-scene-flow.md | Title's Continue (only Title → Overworld exists) | §6 preflight, then commit in SWAP; Continue always targets the Overworld |
| game-state-scene-flow.md | Quit warns of progress since the last save | §4 `has_unsaved_progress()` |
| content-data-definitions.md | Save/Load stores IDs and runtime state, never definitions; an unknown ID is never guessed | §3 participants, `SaveReader.get_id()` with `resolve_alias()` |

## Performance Implications
- **CPU**: a save captures and stringifies tens of kilobytes, a few milliseconds, and only at safe moments. Settings writes are debounced.
- **Memory**: one parsed envelope and the staged sections while loading.
- **Load Time**: settings add one small file read at boot. Preflight runs before the Title fade, inside the request.
- **Disk**: at most three files per slot (`.json`, `.bak.json`, and a transient `.tmp.json`).

## Migration Plan
No code exists to migrate. Build order:
1. **With the first settings story** (Vertical Slice, or earlier if the comfort settings ship in MVP):
   - `SaveFileSystem` and its fake, `SettingsService`, `SettingsSchema`;
   - `settings_views.gd` and `DisplaySettingsApplier`;
   - wiring in `GameRoot._ready()` before `FlashGate`, `UiService` and `PresentationDirector`, replacing the stubs ADR-0005 and ADR-0008 use;
   - a Steam Deck rename probe.
2. **With the remap screen:** the ADR-0003 capture amendment, `validate_bindings`, the `InputCapture` facade (ADR-0008), and the bindings setting.
3. **With the first participant** (Game State's section, then Squad Roster):
   - `SaveService`, `SaveParticipant`, `SaveReader`, `SaveStage`, `save_bootstrap.gd`;
   - the ADR-0002 `payload_commit` hook;
   - Title's Continue and New Game.

## Validation Criteria
- **Unit (fake FS):**
  - a failure injected at each of §5's steps leaves the previous slot loadable;
  - a truncated body reads as `CORRUPT`;
  - a save containing an integer field reloads with a matching hash (the regression test for finding 1);
  - a `version` above the supported one reads as `TOO_NEW`;
  - a file over `max_file_bytes` reads as `TOO_LARGE` without being parsed.
- **Unit (migration and preflight):**
  - a v1 fixture of each participant migrates and stages;
  - an aliased ID resolves;
  - an unknown essential ID fails `preflight`, and **no participant's state changes** (assert before and after).
- **Unit (save moments):** `save_to_slot` returns `NOT_SAFE_MOMENT` during a transition, with the Defeat Prompt open, and in Battle.
- **Unit (settings):**
  - an out-of-range settings field falls back to its default;
  - a changed setting emits `value_changed` for that key only;
  - `clear_bindings()` queues exactly one notice.
- **Integration:**
  - binding `Z` during capture emits no `confirm`;
  - New Game after Quit to Title starts from participant defaults.
- **Code review:** no `ResourceLoader`, `load()`, `str_to_var`, `ConfigFile` or `get_var` on `user://` paths.

## Related
- **Depends on:**
  - `adr-0001-content-data-storage-format.md`;
  - `adr-0002-game-state-scene-flow.md` (amended additively, §6: `payload_commit`; `is_save_safe()` unchanged);
  - `adr-0003-input-system.md` (amended additively, §7);
  - `adr-0005-sprite-camera-presentation.md` (`FlashSettings`);
  - `adr-0006-battle-replay-ownership.md` (`set_speed_settings`);
  - `adr-0008-ui-framework.md` (`pre_setup`, the `UiSettings` interface this ADR's adapter implements, `UiContext.input_capture`).
- **Upcoming:**
  - the Save/Load & Settings GDD (slots, triggers, screens, how damaged saves are presented);
  - the Localization ADR (the `locale` setting);
  - the Audio Manager ADR (volumes).
- **On acceptance:** register in `docs/registry/architecture.yaml` a forbidden pattern for `user://` files loaded as a Resource or Variant, the `save_participant` interface, and `user_data_serialization` = JSON.

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | 6 blocking, all fixed:<br>- hash over re-serialized JSON (fixed: header line hashes the body bytes);<br>- redundant ADR-0002 query (fixed: `is_save_safe()`);<br>- Continue to Camp has no transition row (fixed: always Overworld);<br>- restore in `setup()` can't fail or roll back (fixed: preflight `stage()`, commit in SWAP via `payload_commit`, `reset_to_new_game`);<br>- Core implementing a Presentation interface (fixed: view adapters in the composition root);<br>- the resolver's third holder and incomplete capture (fixed: `GameRoot` applies overrides, `InputCapture` via `UiContext`, `validate_bindings`, fresh press and timeout).<br>Advisories folded in: boot and Content Error independence, `PresentationSettings` delivery, display applier, playtime owner, injected clocks, `has_unsaved_progress`, flush from `quit_hook`, size and type bounds, ID pattern, hash scope, provisional UX choices, `swap_confirm_cancel` |
| 2026-10-22 | godot-specialist | APPROVE WITH NOTES | Probed:<br>- rename overwrite (Windows);<br>- JSON float typing and 2^53;<br>- sorted keys;<br>- `store_string` returns false on failure (not via `get_open_error`);<br>- custom user dir;<br>- sha256 determinism;<br>- `str_to_var` follows `Resource()` with objects off;<br>- a missing `user://saves/` fails;<br>- `WM_CLOSE_REQUEST` reaches nodes.<br>Folded into Verification, §1, §5 and §7 |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22b.md`) | CONCERNS → fixed | Undeclared dependency: §7 uses ADR-0008's `pre_setup` hook, but the Ordering Note said "does not depend on ADR-0008". Fixed: ADR-0008 added to Depends On and Related, and removed from Enables. godot-specialist **F6** (no fsync, and `read_slot` should fall back to `.bak` on `CORRUPT`), **F7** (`JSON.stringify` `full_precision`; RNG state as a string) and **F8** (Deck suspend notification; `use_custom_user_dir` in tests) are advisory, not folded in, and owed before the first save story |
| 2026-10-22 | User | **Accepted** | Explicit instruction (order ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010). Dependencies ADR-0001, 0002, 0003, 0005, 0006 and 0008 are Accepted. No story was Blocked on this ADR. Its additive amendments to ADR-0002 (`payload_commit`) and ADR-0003 (capture mode, `validate_bindings`) are annotated in their Status sections |
