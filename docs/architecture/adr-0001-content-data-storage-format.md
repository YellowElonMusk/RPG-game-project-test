# ADR-0001: Content Data Definitions Storage & Loading Format

## Status
Accepted — amended by ADR-0004 (bootstrap; Accepted 2026-10-22, amendment in effect) and ADR-0007 §7 (Stats range validators register through `ContentBootstrap`; Accepted 2026-10-22, amendment in effect, annotation only) and ADR-0011 §4–§5 (`rule_id` resolution no longer uses `ProjectSettings.get_global_class_list()`; the reserved `FactionRule` record type is defined; `Faction.rule_id` is an ordinary reference to a `faction_rule` record, checked by the generic reference pass; Accepted 2026-10-22, amendment in effect, annotation only) and ADR-0012 §3 (three record types `map` (`map_`), `encounter` (`enc_`) and `occupation_stage` (`ostage_`), plus `faction.patrol_archetype_id`; Accepted 2026-10-23, amendment in effect, annotation only)

## Date
2026-10-21

## Last Verified
2026-10-21

## Decision Makers
User, Claude (orchestrating session), reviewed by godot-specialist and technical-director (TD-ADR)

## Summary
Content Data Definitions needs a concrete way to store and load its typed
records (Faction, Character, Enemy, Move, QuirkState, Combo, Item) in Godot
4.7.2. Decided: custom `Resource` subclasses saved as `.tres` files, one class
per record type, with all cross-record references stored as plain ID strings
validated by a custom loader — never direct Resource-to-Resource links.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH — post-LLM-cutoff version |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (no dedicated Core/data module reference exists) |
| **Post-Cutoff APIs Used** | `ResourceLoader.list_directory(path) -> PackedStringArray` (added 4.4, after the May 2025 cutoff) — **empirically verified present and correct in this exact pinned build** (4.7.2.stable.official): confirmed via a throwaway headless script that it exists, and that it lists `.tres` files in a directory while correctly excluding non-resource files (tested against a folder of `.md` files, which it returned empty for). It is part of Godot's resource virtual filesystem, not raw OS directory listing, which is why it (unlike `DirAccess`) is the safe choice against an exported build (see Decision). |
| **Verification Required** | Re-confirm `list_directory()`'s behavior specifically against an **exported** build (the empirical check above ran from the raw project directory, not a packaged export) before the first real content migration ships — see Validation Criteria. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (ADR-0001, nothing precedes it) |
| **Enables** | Faction Rule Modifiers' `Faction.rule_id` field becoming concrete; future Quirk State System, Combo System & Codex, Items/Equipment & Shops data authoring |
| **Blocks** | The Content Data Definitions migration already in progress (moving Turn Battle System's and Faction Rule Modifiers' hardcoded specials/enemy stats into data) |
| **Ordering Note** | Migration Step 0 (characterization tests, below) must land before Step 3 (any factory switches to catalog lookups) — this ordering is itself part of the decision, not a detail left to implementation. |

## Context

### Problem Statement
`content-data-definitions.md` explicitly defers "how the data is stored and
loaded in Godot" to an ADR. Nine Core Rules (record types, IDs, references,
data-only, field ownership, text, read-only-at-runtime, validation, lookup)
and a Ready/Failed load state machine must all be satisfiable by whatever
format is chosen, and the project's current hardcoded battle content (4 squad
specials, 5 enemy types across 2 factions) needs an immediate migration
target.

### Constraints
- Solo developer — authoring overhead matters as much as runtime correctness.
- Godot 4.7.2, GDScript only (no C#/GDExtension in this project).
- Must support the full validation rule set (Rule 8) without inventing a
  second schema language.
- References must be ID strings only (Rule 3) — never file paths or direct
  object references — so IDs stay stable across refactors and saves only
  ever store IDs.
- The project's coding standard prefers dependency injection over
  singletons. This ADR's access pattern (below) is an explicit, justified
  exception, not an oversight.

### Requirements
- Must support 7 record types today (Faction, Character, Enemy, Move,
  QuirkState, Combo, Item) plus reserved future types (FactionRule,
  AIProfile, Encounter/Region, Conversation, LoyaltyQuest, Ending) without a
  format change.
- Must produce a Ready/Failed load state other systems can block on (Game
  State & Scene Flow's boot sequence already specifies this).
- Must support record lookup by type and ID, existence checks, enumeration in
  a fixed order, and alias resolution (Rule 9).
- Must report every validation problem found per load, not just the first
  (Rule 8), including unknown fields, missing required fields, and unparsable
  files — not just reference/range errors (see Decision's validation
  mechanism).
- Must be independently runnable as a standalone headless check (Rule 8: "also
  as a standalone headless check, so tests and CI can run it").

## Decision

Every record type gets its own Godot `Resource` subclass (`class_name`,
`extends Resource`), with all scalar/enum fields as typed `@export` vars, and
every cross-reference field (`nation_id`, `move_ids`, `faction_id`, etc.)
typed as `String`/`PackedStringArray`, holding the referenced record's `id` —
never a direct `@export var other: SomeResource` reference. Each record is
authored as one `.tres` file under `data/[type_plural]/[id].tres` (e.g.
`data/characters/char_baguette_thrower.tres`), so one record = one file = one
diffable unit, and **the filename (minus extension) must equal the record's
own `id` field** — checked by the validation pass, not just a convention.

### File discovery
`ContentCatalog.load_all()` enumerates files with **`ResourceLoader.list_directory(path)`**,
recursed per subdirectory under `data/` — not `DirAccess`, and not a literal
"glob". This is a deliberate, verified choice (see Engine Compatibility): it
is part of Godot's resource virtual filesystem, so it works identically in
the editor and against an exported build, where `.tres` files are converted
to a binary format with `.remap` companions that a raw `DirAccess` directory
listing would surface instead of (or alongside) the `.tres` names it expects.
`ResourceLoader.list_directory()` abstracts that away.

### Access pattern (resolves the DI-vs-singleton tension)
`ContentCatalog` is implemented as a Godot **autoload singleton**, as an
explicit, documented exception to the project's "dependency injection over
singletons" standard — justified because: (1) it is read-only after `Ready`
(Rule 7), so it carries none of the mutable-shared-state risk DI avoids;
(2) every static factory this project already has
(`SquadSpecials.make_speak_to_the_manager()`, `BureaucratiaRule.make_clerk()`,
etc.) is a parameterless `static func`, which cannot accept an injected
dependency without changing every call site across already-shipped code
(`battle_debug_harness.gd`, `battle_hud_demo.gd`, `chapter_flow_demo.gd`,
`chapter_flow.gd`) to thread a catalog reference through; (3) Godot autoloads
are guaranteed to run their `_ready()` before the main scene's, so
`ContentCatalog.load_all()` runs at `_ready()` and every other scene's own
`_ready()` can safely call `ContentCatalog.get_record(...)` immediately,
with no extra boot-sequencing code needed anywhere else. This autoload does
not yet have a scene to register in (Game State & Scene Flow, which per its
own GDD starts this load at boot, is not built) — until it exists, the
autoload's own `_ready()` is the bootstrap; `project.godot` must list it
under `[autoload]` as part of implementing this ADR.

> **Amendment pending — ADR-0004 (Content Boot Ordering).** Reason (3) and
> the bootstrap sentence above are replaced: `load_all()` is not called from
> the autoload's `_ready()`. `ContentBootstrap.run()` registers every
> vocabulary and validator and then loads, called from `GameRoot._enter_tree()`
> (and from harness scenes and `validate-content.gd`). Measured on 4.7.2, an
> autoload's `_ready()` actually runs *after* the main scene's `_enter_tree()`,
> so the premise of reason (3) did not hold. The autoload remains the
> read-only access pattern (reasons 1 and 2 stand).

**Characterization tests do not use the catalog.** They are written against
*today's* hardcoded factories, before migration, specifically to pin current
behavior; the same tests, unchanged, are run again after migration to prove
the catalog-backed factories produce identical results. No fixture catalog is
needed for them.

### Validation mechanism (resolves the "Resource types catch this for free" overstatement)
A typed `@export` field always has a default value and Godot silently drops
unrecognized properties when loading a `.tres`, so **neither unknown-field
typos nor "missing" required fields are caught by `Resource` loading alone.**
`ContentCatalog`'s validation pass therefore does three things beyond
instantiating each `Resource`:
1. **Unknown fields**: read each `.tres` file's raw text (`FileAccess`) and
   parse its flat `key = value` property list (the text-resource format's
   `[resource]` section — a simple line scan, not a full parser), then diff
   against the loaded instance's own `get_property_list()` (filtered to
   storage/script-declared properties). Any raw property absent from that
   list is an unknown-field error naming the file and the field.
2. **Missing required fields**: required fields are validated by their
   existing Rule 6/Rule 8 checks (a required text field that is empty or
   whitespace-only is already an error; a required numeric field outside its
   owning GDD's documented range, e.g. `max_hp` 1–999, is already an error).
   "Missing" and "invalid" collapse into the same detectable condition this
   way — no separate missing-ness tracking is needed, only the discipline
   that every required field's valid range/non-empty rule is actually
   enforced, not just the reference/uniqueness checks.
3. **Unparsable files**: `ResourceLoader.load(path)` returns `null` on
   failure (and writes to the engine log independently). The catalog must
   check for `null`, record its own validation error naming that file path,
   and continue loading the rest of the set — never abort early.

**Standalone headless validation** (Rule 8's CI requirement): a small script
at `res://.claude/scripts/validate-content.gd` (mirroring the existing
`godot-parse-check.gd` pattern) calls `ContentCatalog.load_all()` directly and
exits with the error count as its exit code, runnable via
`godot --headless -s res://.claude/scripts/validate-content.gd` with no scene
needed.

### EffectDescriptor adapter (resolves the Move-shape mismatch)
The GDD's `Move` record stores `effects` as a list of EffectDescriptors
(`{type, ...params}`); today's runtime `Move` (`src/battle/move.gd`) is a
`RefCounted` with a `special_effect` enum plus `power`/`effect_rounds` fields,
which do not match. Migration does **not** change `BattleCore`'s runtime
`Move`/`Combatant` shapes — instead, each static factory becomes an
**adapter**: it calls `ContentCatalog.get_record(...)` for its `MoveData`/
`CharacterData`/`EnemyData` record, reads its EffectDescriptors, and
constructs today's runtime `Move`/`Combatant` objects exactly as it does now,
just sourcing the numbers from the catalog instead of a hardcoded `const`.
`BattleCore` itself never touches a catalog record directly.

The EffectDescriptor `type` values this migration introduces: `stun`,
`heal_party`, `heal_single`, `damage_debuff`, `direct_damage` — one per
existing `SpecialEffect` enum value. **Attack and Defend are not migrated to
records**: they are universal moves every combatant already has
(`Move.make_attack()`/`make_defend()`), not authored per-character content,
and stay as code-side factories.

Per the sibling `turn-battle-system.md` GDD's own open question (quirk-state/
combo relationship, `INTENT UNKNOWN`), these five EffectDescriptor types are
marked **provisional** under Rule 5: they may be renamed or restructured once
Quirk State System is designed, and are migrated *after* the stable data
(enemy stat blocks, faction tuning, faction records) specifically so that
risk lands on the smaller, later part of the migration — see Migration Plan.

### Vocabulary ownership (resolves the Foundation-depends-upward concern)
Rule 8 requires the catalog to check that every EffectDescriptor `type` is
"known" and that `Faction.rule_id` resolves — but the vocabularies for both
belong to Feature-layer systems (Turn Battle System's effect types; Faction
Rule Modifiers' `FactionRule` classes), which sit *above* this Foundation
system in the dependency graph. Resolution: **owning systems register their
known vocabulary with the catalog before validation runs**, not the other
way around. Concretely: `Turn Battle System`'s own startup code (not this
ADR's `ContentCatalog`) calls a registration method naming its five
EffectDescriptor types before `ContentCatalog.load_all()`'s Validating phase
begins; `Faction Rule Modifiers` is responsible for resolving `rule_id`
strings to its own `BureaucratiaRule`/`MegaCorpRule` classes (via
`ProjectSettings.get_global_class_list()` — GDScript `class_name` classes are
not in `ClassDB`, so this lookup cannot live in the Foundation layer either).
Stats & Damage Resolution's documented ranges (`max_hp` 1–999, etc.) are read
by the catalog from a small shared constants reference that system owns, not
duplicated as literals inside `ContentCatalog`.
> **Amended by ADR-0007 §7 (Accepted 2026-10-22):** the catalog does not read
> a Stats constants reference. Stats & Damage Resolution registers its range
> validators (`StatsValidators`, bound to `StatsConfig`) through
> `ContentBootstrap.run()` → `register_record_validator()` (ADR-0004 §4), so
> `src/data/` imports nothing from Core.

### Architecture Diagram
```
data/factions/*.tres   ─┐
data/characters/*.tres  ─┤
data/enemies/*.tres     ─┼──► ContentCatalog.load_all() ──► Validate (Rule 8) ──► Ready | Failed
data/moves/*.tres       ─┤    (ResourceLoader.list_directory,  (ID/ref/range/unknown-field/
data/quirks/*.tres      ─┤     recursed per subdirectory)       parse-failure checks)
data/combos/*.tres      ─┤
data/items/*.tres       ─┘
                                                     │
                                                     ▼
                              get_record(type,id) / has_record / all_records / resolve_alias
                                                     │
                             ┌───────────────────────┼───────────────────────┐
                             ▼                       ▼                       ▼
                    Turn Battle System      Faction Rule Modifiers      UI Framework
                    (Character/Enemy/Move)  (Faction.rule_id)           (display/icon/color)
```

### Key Interfaces
- `ContentCatalog.get_record(type: StringName, id: String) -> Resource` —
  **not** `get()`: that name collides with `Object`'s own built-in
  single-argument `get(property)`, which every GDScript class inherits.
- `ContentCatalog.has_record(type: StringName, id: String) -> bool` — not
  `exists()`, for naming symmetry with `get_record`/`all_records`.
- `ContentCatalog.all_records(type: StringName) -> Array[Resource]` (sorted
  by `id`) — not `all()`, same reason.
- `ContentCatalog.resolve_alias(id: String) -> String` (no collision, name
  unchanged).
- `ContentCatalog.register_known_effect_types(system: StringName, types: PackedStringArray) -> void`
  and the equivalent for faction-rule-class resolution — the vocabulary-
  registration calls described above, invoked by Feature-layer systems before
  `load_all()`'s Validating phase.
- *(Amendment pending, ADR-0004)* `ContentCatalog.register_record_validator(type: StringName, validator: Callable) -> void`:
  a per-record-type semantic validator, run during Validating and rejected once `load_all()` has started.
- `ContentCatalog.state -> State` (`UNLOADED | LOADING | VALIDATING | READY | FAILED`)
- Record base shape: every record Resource exports `id: String` and, where
  Rule 2 applies, `aliases: PackedStringArray`.

### Implementation Guidelines
- Record classes must never contain logic beyond basic getters — Rule 4
  ("data only, no logic") is enforced at the class level: no record
  `Resource` script may define a method that computes a gameplay effect.
- Cross-references must be typed `String`/`PackedStringArray` fields holding
  IDs, never `@export var x: OtherResourceType` — a direct Resource
  reference would violate Rule 3 and reintroduce file-path coupling through
  Godot's own `.tres` `ExtResource` mechanism. **The validation pass itself
  must reject any record script that declares such a field** (inspect the
  script's property list for an Object/Resource-typed export) — this is a
  load-time guarantee, not just a `/code-review` convention.
- Record scripts live at a stable path (e.g. `src/data/records/`) and are
  never renamed casually: every `.tres` references its script by path via
  `ExtResource`, so moving a record script's file still touches every data
  file that uses it, even though the *data* itself only ever references
  other records by ID.
- Records are never used as live runtime state. Every consumer (a factory
  function) copies a record's field values into its own runtime object
  (`Combatant`, `Move`) at construction time — today's factories already do
  this, and migration must preserve it. `ResourceLoader.load()`'s default
  `CACHE_MODE_REUSE` means a record `Resource` instance is shared across
  every caller in the session; nothing may mutate a record's fields after
  load.
- The catalog must load once per session; `Ready` is terminal. A second
  `load_all()` call in the same session must be rejected or is a programmer
  error, not a supported reload path.
- Validation must run over the *complete* set before reporting (Rule 8's
  "every problem, not just the first") — never fail-fast on the first bad
  record.
- `.tres` files are the authored source of truth; nothing in Godot's import
  pipeline (`.godot/imported/`) is content — and for plain `.tres` text
  resources specifically, nothing is written there at all (no `.import`
  file is generated for a `.tres` the way one is for a texture or audio
  asset). This only matters for binary assets referenced *inside* a record
  (an icon field, etc.), never the record `.tres` files themselves.
- `class_name` global registration happens once at project/engine startup,
  before autoloads run, so `ContentCatalog`'s `_ready()` load pass always
  sees registered record classes. Do not call `load_all()` from another
  autoload's `_init()` — that is the one ordering that could run ahead of
  class registration.
  *(Amendment pending, ADR-0004: there is no `_ready()` load pass. Catalog
  state is set up in initializers or `_init()`, `_ready()` must not touch it,
  and `load_all()` is called only by `ContentBootstrap.run()`.)*

## Alternatives Considered

### Alternative 1: Plain JSON files
- **Description**: one `.json` file per record type (or per record), parsed
  via Godot's `JSON` class into a plain `Dictionary`-backed in-memory record.
- **Pros**: trivially mod-friendly for a non-technical editor (no Godot
  editor or resource format knowledge needed); engine-agnostic format.
- **Cons**: no compile-time or Inspector-level type checking — every field's
  type, required-ness, and enum validity must be hand-validated in GDScript;
  no Inspector authoring UI; `JSON.parse()` gives back loosely-typed
  `Variant`/`Dictionary` data requiring manual casting throughout.
- **Rejection Reason**: the authoring-ergonomics cost (no Inspector, no type
  safety) outweighs the modding benefit for a solo developer who is also the
  sole content author at this stage; modding is explicitly deferred in the
  GDD itself ("Mod loading itself is out of scope here").

### Alternative 2: Godot `ConfigFile` / custom text format
- **Description**: `.cfg`/`.ini`-style key-value sections, one section per
  record, parsed via `ConfigFile`.
- **Pros**: built into Godot, no parser to write.
- **Cons**: `ConfigFile`'s flat key=value model has no native support for
  nested structures (a Move's `effects` list of EffectDescriptors, a
  Character's `move_ids` array) without hand-rolled string encoding; no
  Inspector authoring; weakest fit of the three for this GDD's record
  richness.
- **Rejection Reason**: structurally the worst match for nested,
  list-and-reference-heavy records; rejected once the record shapes in Rule
  1's table were reviewed.

## Consequences

### Positive
- Inspector-based authoring for every record type — a solo dev adds a new
  enemy or character by filling in a form, not hand-writing a schema, for
  every field *except* `effects` (see Negative — Array[Dictionary] is awkward
  in the Inspector specifically).
- `.tres` is Godot's native text-resource format — readable in a diff, plays
  well with git.
- One file per record keeps the "one unit of content = one file" granularity
  that already matches how stories/epics are organized in this project.
- `ResourceLoader.list_directory()` makes file discovery correct in both the
  editor and an exported build without separate code paths.

### Negative
- Less mod-friendly out of the box than JSON — a modder needs to understand
  Godot's `.tres` text format and this project's specific Resource script
  classes. Accepted because modding is explicitly out of scope for this GDD.
- Resource's type safety only catches a *wrong type or enum value* at author
  time — it does **not** catch an unknown (typo'd) field or a field left at
  its default when it was meant to be set; those need the explicit
  raw-text-diff and required-range mechanisms described in Decision. This is
  a real authoring-time gap, not fully closed by the format choice alone.
- `ContentCatalog`'s validation pass (ID uniqueness, reference resolution,
  cycle detection, range checks, unknown-field detection, parse-failure
  handling) must still be fully hand-written regardless of format.
- Editing an `Array[Dictionary]` of EffectDescriptors in the Godot Inspector
  is awkward (no structured editor for arbitrary per-element keys) — this
  weakens the "fill in a form" authoring benefit specifically for `Move`'s
  richest field. Accepted for now; a custom Inspector plugin is a possible
  future improvement, out of scope for this ADR.
- A record author must remember the "ID strings only, never direct Resource
  references" rule; mitigated by making the validation pass itself reject
  violations (Implementation Guidelines), not left to review discipline
  alone.

## Risks
- **Risk**: a future record class accidentally uses a direct `@export var x:
  SomeResource` reference instead of an ID string, silently reintroducing
  path coupling.
  **Mitigation**: the validation pass rejects this at load time (Implementation
  Guidelines) — stronger than relying on `/code-review` alone, though that
  remains a useful second check.
- **Risk**: `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE` — repeated
  loads of the same path return the same cached instance. Desirable within a
  session (`Ready` is terminal), but if a future test harness runs multiple
  iterations in one engine process without restarting, edits to a `.tres` on
  disk won't be picked up without `CACHE_MODE_REPLACE`.
  **Mitigation**: run each verification pass in a fresh process (the
  characterization tests below do this, one process per run, matching
  stories 003-006's existing pattern).
- **Risk**: HIGH knowledge-risk engine version (4.7.2, post-cutoff).
  `ResourceLoader.list_directory()` specifically is a post-cutoff API.
  **Mitigation**: empirically verified present and correct against this
  exact pinned build (Engine Compatibility) — not asserted from training
  data. Exported-build behavior still needs the same empirical check before
  shipping (Verification Required).
- **Risk**: the Foundation-layer catalog's validation needs vocabulary
  (known EffectDescriptor types, known FactionRule classes) that Feature-
  layer systems own, creating an apparent upward dependency.
  **Mitigation**: resolved by the registration pattern in Decision — Feature
  systems register their vocabulary with the catalog before validation runs,
  so the catalog's own code never hardcodes or imports Feature-layer
  knowledge.
- **Risk**: migrating the squad specials' EffectDescriptor types now, ahead
  of Quirk State System's design, risks a second migration once that system
  exists (e.g. if `stun` becomes `apply_quirk_state: quirk_complained`).
  **Mitigation**: marked provisional (Rule 5) and sequenced last in the
  Migration Plan, so the risk lands on the smaller, already-isolated part of
  the migration, not the stable enemy/faction data.
- **Risk**: MegaCorp's enemy AI currently keys behavior off `enemy.display_name == "Middle Manager"` —
  a string comparison against player-facing text. Rule 2 explicitly allows
  display names to change freely; doing so today would silently change AI
  behavior.
  **Mitigation**: Migration Plan's enemy-move step converts named attacks to
  `Move` records and has the AI key off the enemy's stable `id`, not its
  `display_name`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| content-data-definitions.md | Rule 1 (record types table) | One Resource subclass per record type, matching the table's fields exactly |
| content-data-definitions.md | Rule 2 (permanent IDs, aliases) | `id: String` and `aliases: PackedStringArray` on every record's base shape; filename-equals-id checked by validation |
| content-data-definitions.md | Rule 3 (references by ID only) | Cross-reference fields typed as ID strings; validation pass rejects any direct Resource-typed export field |
| content-data-definitions.md | Rule 4 (data only, no logic) | Record classes forbidden from defining behavior methods; EffectDescriptors stored as plain `Array[Dictionary]` |
| content-data-definitions.md | Rule 7 (read-only at runtime) | `ContentCatalog.state` is terminal at `Ready`; no write-back API exists; Implementation Guidelines forbid mutating a loaded record |
| content-data-definitions.md | Rule 8 (validation: structure, references, ranges) | `ContentCatalog`'s validation pass, run once over the complete set, reporting every problem |
| content-data-definitions.md | Rule 8 (validation: unknown fields, missing fields, parse failures) | Explicit raw-text diff mechanism, required-range convention, and null-checked `ResourceLoader.load()` — see Decision's validation mechanism subsection |
| content-data-definitions.md | Rule 8 (standalone headless check) | `res://.claude/scripts/validate-content.gd`, run via `godot --headless -s` |
| content-data-definitions.md | Rule 9 (lookup operations) | `get_record`/`has_record`/`all_records`/`resolve_alias` as the Key Interfaces above |
| content-data-definitions.md | States and Transitions table | `ContentCatalog.state` enum matches `Unloaded → Loading → Validating → Ready\|Failed` exactly |
| game-state-scene-flow.md | Rule 13 / Boot | Boot can block on `ContentCatalog.state == READY` before leaving the boot mode |
| turn-battle-system.md | Open Question: Content Data Definitions migration | This ADR is the prerequisite; EffectDescriptor types marked provisional per that GDD's own open question |
| faction-rule-modifiers.md | Open Question: Content Data Definitions migration; `Faction.rule_id` | `rule_id` resolved by Faction Rule Modifiers' own code (vocabulary ownership, above), not Foundation |

## Performance Implications
- **CPU**: negligible — load happens once at boot, not per-frame;
  validation is O(records × references), trivial at this project's content
  scale (tens of records, not thousands).
- **Memory**: every record stays resident for the session (Rule 7,
  read-only catalog) — acceptable at this scale.
- **Load Time**: one `ResourceLoader.load()` per file at boot; negligible at
  current/projected record counts.
- **Network**: not applicable (single-player, no content sync).

## Migration Plan
0. **Write characterization tests** under `tests/unit/battle/` (this
   directory does not exist yet — this step creates it) that pin today's
   exact values and outcomes for the four squad specials, the five enemy
   types, and both faction rules, using a seeded RNG. These tests run against
   **today's hardcoded code**, before any catalog lookup exists, and must
   still pass unchanged after every later step. This directly replaces the
   original plan's incorrect assumption that "the existing headless
   verification scripts from stories 003-006" could serve this purpose — they
   don't exist as retained test files (those stories closed with test
   evidence waived at `qa.level: minimal`, leaving only screenshots and
   throwaway demo/harness scenes, none of which can prove behavior is
   unchanged after a refactor).
1. Build `ContentCatalog` (as the autoload described in Decision) and the
   record Resource script classes (new code; no existing code changes yet).
   *(Amendment pending, ADR-0004: the load entry point is
   `src/boot/content_bootstrap.gd`, not the autoload's `_ready()`; the script
   declares `class_name ContentCatalogService`, and `ContentCatalog` gains
   `register_record_validator(type, validator)`.)*
2. Author `.tres` records for the **stable data first**: the Clerk/Supervisor/
   Security Drone/Middle Manager/CEO `Enemy` records (including their named
   attacks as `Move` records, keyed by `id` not `display_name` — resolves the
   AI risk above), and the two built `Faction` records (Bureaucratia,
   MegaCorp) — `rule_id` stays a plain string naming the existing
   `BureaucratiaRule`/`MegaCorpRule` GDScript classes, resolved via
   `ProjectSettings.get_global_class_list()` by Faction Rule Modifiers' own
   code, until that GDD's `FactionRule` record type itself exists.
3. Update `src/battle/factions/{bureaucratia,megacorp}.gd`'s roster factories
   and enemy-AI action selection to read from `ContentCatalog.get_record(...)`
   instead of their current hardcoded `const`s and static methods — the
   public API (`MegaCorpRule.make_ceo()`, etc.) stays the same shape. Re-run
   the Step 0 characterization tests; they must still pass.
4. Author `.tres` `Move` records for the four squad specials, marked
   **provisional** (Rule 5) per the EffectDescriptor adapter design above,
   and update `src/battle/squad/specials.gd`'s factories the same way. Re-run
   the Step 0 characterization tests again.
5. Point `Validation Criteria`'s regression check at the Step 0 tests (not
   screenshots or demo scenes).

## Validation Criteria
- `ContentCatalog` loads all current content with zero validation errors.
- The Step 0 characterization tests (written before migration, re-run
  unchanged after each migration step) all still pass.
- The catalog loads and validates cleanly in an **exported** Windows build,
  not only when run from the raw project directory — specifically
  re-verifying `ResourceLoader.list_directory()`'s behavior there, since the
  empirical check performed for this ADR only covered the unexported case.
- A deliberately malformed `.tres` fixture for each of these cases produces
  the expected named validation error, not a crash or silent skip: a bad/
  duplicate ID, a dangling reference, an unknown EffectDescriptor `type`, an
  **unknown (typo'd) field**, and an **unparsable file**.

## Related
- `design/gdd/content-data-definitions.md` (the GDD this ADR implements
  storage for)
- `design/gdd/turn-battle-system.md`, `design/gdd/faction-rule-modifiers.md`
  (reverse-documented GDDs whose Open Questions this ADR partially resolves)
- `design/gdd/systems-index.md` (Content Data Definitions, Foundation layer)

## Review History
- **Engine specialist (godot-specialist)**: CONFIRMED, with 4 precision
  additions (glob API doesn't exist as such, `.tres` import-cache scope,
  `CACHE_MODE_REUSE` behavior, `class_name`/autoload ordering) — all folded
  into Implementation Guidelines and Risks above.
- **Technical Director (TD-ADR)**: CONCERNS — 6 blocking items (method-name
  collision with `Object.get()`; nonexistent regression test dependency;
  Move/EffectDescriptor shape mismatch; overstated validation coverage;
  unspecified/export-unsafe file discovery; unspecified access pattern) and 7
  advisory items, all addressed in this revision. Re-review recommended
  before moving Status to Accepted, in a fresh session per the standard
  `/architecture-review` guidance (never in the same session that authored
  the ADR).
- **2026-10-21 — amendment proposed by ADR-0004 (Content Boot Ordering)**:
  an additive annotation of four passages (Access pattern reason 3 and the
  bootstrap sentence; the `_ready()` load-pass guideline; Migration Step 1's
  load entry point; Key Interfaces gains `register_record_validator()`). The
  original text is kept. The amendment takes effect when ADR-0004 is Accepted.
- **2026-10-22 — ADR-0004 Accepted**: the bootstrap amendment above is now in
  effect. Where the annotated passages and ADR-0004 differ, ADR-0004 governs.
