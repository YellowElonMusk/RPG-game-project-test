# Content Data Definitions

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-10-20
> **Last Verified**: 2026-10-13
> **Implements Pillar**: The Joke Is the Mechanic · Misfits Make the Combo · Readable in One Turn

## Summary

Content Data Definitions is the read-only catalog of every authored game record: factions, misfit characters, enemies, moves, quirk states, combos and items. It defines how those records are identified, cross-referenced and validated. Players never see it, but every fight, menu and joke is built from it. It exists so gameplay values live in data rather than code, so each punchline and its mechanic sit in one record (Pillar 1), and so new content stays a data task that is ready for post-launch modding.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Content Data Definitions is the single catalog of everything the game's authors define as data rather than code: the squad's misfit characters, enemies, factions, quirk states, combos, and items, plus the identity, schema and validation rules every other system relies on to read that catalog. It is a data layer, not a gameplay system. The player never touches it directly, but every fight, conversation and menu is built from records it defines.

It exists to make three project commitments real. First, gameplay values are data, never hardcoded (coding standard), so balance changes and new content don't require code changes. Second, the joke and the mechanic live in one record (Pillar 1, The Joke Is the Mechanic): a quirk's punchline text, icon and effect are defined together, so they cannot drift apart. Third, adding a new faction, recruit, or combo should be a data-and-asset task, not a new subsystem, which keeps the scope realistic for a solo developer. The catalog also holds each faction's art-bible properties (signature color, base shape, rule-UI shape), so presentation and UI read them instead of hardcoding them.

Content ships inside the game, but every record has a stable, human-readable ID and the schema is documented, so player-made mods can be supported after launch without redoing the data model. Mod loading itself is out of scope here. How the data is stored and loaded in Godot is an implementation decision for an ADR, not for this GDD.

## Detailed Design

### Core Rules

**1. Record types.** The catalog holds these record types. Types marked *reserved* are defined by the owning GDD later but must follow rules 2–8.

| Type | ID prefix | Purpose | Key fields | Field meaning owned by |
|---|---|---|---|---|
| Faction | `faction_` | A human nation or alien civilization | `display_name`, `kind` (`human_nation` \| `alien`), `base_shape` (`organic` for nations; `square` \| `circle` \| `wedge` \| `star` for aliens), `signature_color` (hex; **alien only**), `backup_icon_id` (alien only), `rule_id` (alien only → FactionRule) | Art bible §3–4 (shape, color); Faction Rule Modifiers (`rule_id`) |
| Character | `char_` | A recruitable squad misfit | `display_name`, `nation_id` (→ Faction, `human_nation`), `archetype_line` (one-sentence description of the prop/pose joke), `stat_block`, `move_ids` (→ Move), `signature_move_id` (→ Move, unlocked by loyalty), `sprite_set_id`, `portrait_id` | Stats & Damage (`stat_block`); Turn Battle (`move_ids`); Leveling & Loyalty (`signature_move_id`) |
| Enemy | `enemy_` | A hostile combatant, including bosses | `display_name`, `faction_id` (→ Faction, `alien`), `is_boss`, `stat_block`, `move_ids`, `ai_profile_id` (→ AIProfile, *reserved*), `sprite_set_id`, `reward` | Stats & Damage (`stat_block`, `reward`); Enemy AI (`ai_profile_id`) |
| Move | `move_` | A command a combatant can use | `display_name`, `target_type`, `cost`, `effects` (list of EffectDescriptor), `animation_id`, `flavor_text` | Turn Battle (`target_type`); Stats & Damage (`cost`) |
| QuirkState | `quirk_` | A comedic status applied to a target (Complained, Unionized, Gone Viral, Notarized) | `display_name`, `icon_id`, `description`, `rule_text` | Quirk State System (meaning, duration, stacking) |
| Combo | `combo_` | A named payoff of cashing quirk states | `display_name` (title-card text), `required_state_ids` (→ QuirkState), `required_character_ids` (→ Character; empty = any), `effects`, `punchline_text`, `animation_id`, `codex_text` | Combo System & Codex |
| Item | `item_` | A consumable, piece of equipment, or key item (reserved for Vertical Slice; no MVP records required) | `display_name`, `description`, `kind` (`consumable` \| `equipment` \| `key`), `effects`, `price` | Items, Equipment & Shops |
| *reserved* | | FactionRule, AIProfile, Encounter/Region, Conversation, LoyaltyQuest, Ending | | Faction Rule Modifiers; Enemy AI; Overworld; Dialogue; Leveling & Loyalty; Faction Reputation |

Character and Enemy are deliberately separate types: each has fields the other does not (loyalty data only on characters, AI profile and rewards only on enemies). To avoid duplicating shared definitions they reuse two sub-records, `stat_block` and `move_ids`, which are defined once.

**2. Identity.** Every record has an `id`: lowercase ASCII snake_case, starting with its type prefix, at most 64 characters, unique across the whole catalog (e.g. `char_baguette_thrower`, `quirk_complained`, `combo_overdue_notice`). IDs are permanent. Once a record has shipped or been written to a save file, its ID is never changed or reused. A renamed or merged record carries the old ID in an `aliases` list so old saves still resolve. Display names can change freely.

**3. References.** Records refer to each other by ID only, never by file path or object. Art and audio are referenced by *asset ID* (e.g. `sprite_set_id`), which the presentation systems map to files; this catalog never names a file path.

**4. Data only, no logic.** Records contain values, enums, references, text and typed EffectDescriptors. An EffectDescriptor is `{type, ...parameters}`. The vocabulary of `type` values and what each parameter means belongs to the system that interprets it (damage/heal → Stats & Damage; apply/consume a quirk state → Quirk State System; faction hooks → Faction Rule Modifiers). This system stores descriptors and checks that the `type` is known; it never interprets or runs them.

**5. Field ownership.** This GDD owns the record types, ID and reference rules, loading, validation, and lookup. The meaning, valid range and balance of each field belong to the GDD named in the table. A field whose owning GDD does not exist yet is **provisional**: it may change when that GDD is approved, and the change is made in that GDD and then reflected in this table.

**6. Text.** All player-visible strings (names, descriptions, flavor text, punchlines) are plain-text fields in the records, kept separate from logic so a later localization pass can extract them mechanically. Localization itself is deferred (see Open Questions).

**7. Read-only at runtime.** After a successful load the catalog is immutable. Systems look definitions up by ID and keep their own runtime state (current HP, active quirk states, party membership) keyed by ID. Nothing writes back into the catalog, and save files store IDs plus runtime state only.

**8. Validation.** Validation runs on every load and also as a standalone headless check, so tests and CI can run it. It checks that: required fields are present; field types and enums are valid; IDs are well-formed and unique (aliases included); every reference resolves to a record of the correct type; every EffectDescriptor `type` is known; `signature_color`, `backup_icon_id` and `rule_id` appear only on `alien` factions; Faction `base_shape` matches its `kind`; and `stat_block` fields and `reward` fields are within the ranges their owning GDD defines (Stats & Damage Resolution F1, Rule 12): `max_hp` 1–999, `max_mp` 0–99, `attack`/`defense`/`speed` 1–99, `reward.xp` and `reward.money` 0–9999. `Move.cost` is a non-negative integer. A value outside its range is an **error** naming the record and field. It reports **every** problem found, not just the first, in two severities. **Errors** block: any error puts the catalog in the Failed state, and the game does not start with partially loaded content in either debug or release builds. **Warnings** are reported but never block (see Edge Cases for which problems are which). Handling of invalid modded content is deferred to the post-launch mod feature.

**9. Lookup.** Other systems read the catalog through four operations: `get(type, id)` returns a definition or an error, `exists(type, id)`, `all(type)`, and `resolve_alias(id)`. `all(type)` returns records in a fixed order sorted by ID, so tests and saves behave identically on every run.

### States and Transitions

| State | Meaning | Enters from | Exits to |
|---|---|---|---|
| Unloaded | Nothing read yet (game just started) | start | Loading |
| Loading | Reading all record files | Unloaded | Validating |
| Validating | Running the rule 8 checks over the full set | Loading | Ready (zero errors) \| Failed (one or more errors) |
| Ready | Catalog is immutable and serving lookups | Validating | — (terminal for the session) |
| Failed | Errors reported; no content is served | Validating | — (fix the data and restart) |

Game State & Scene Flow must wait for Ready before leaving the boot state. Lookups made in any other state return an error, never partial data.

### Interactions with Other Systems

| System | Reads from this catalog | Notes |
|---|---|---|
| Game State & Scene Flow | Load status (Ready / Failed) | Starts the load at boot; blocks until Ready |
| Stats & Damage Resolution | `stat_block`, `reward`, cost fields | Owns the meaning and ranges of these fields |
| Turn Battle System | Moves, enemies, characters | Owns `target_type` and move semantics |
| Quirk State System | QuirkState records | Owns state semantics (duration, stacking, interaction) |
| Combo System & Codex | Combo records; QuirkState and Character references | Owns combo matching rules and Codex behavior |
| Faction Rule Modifiers | Alien Faction records → `rule_id` | Defines the FactionRule record type (reserved) |
| Enemy AI | Enemy `ai_profile_id` | Defines the AIProfile record type (reserved) |
| Squad Roster & Recruitment | Character records | Owns join/leave conditions; they are not stored on the record |
| Items, Equipment & Shops | Item records | Vertical Slice |
| Dialogue, Banter & Quests | Character IDs as speakers | Dialogue defines its own record types, following rules 2–8 |
| Overworld Exploration & Encounters | Enemy IDs in encounter tables | Defines Encounter/Region types (reserved) |
| Sprite & Camera Presentation | `sprite_set_id`, `animation_id`, faction color and shape | Maps asset IDs to files |
| UI Framework | Display names, icons, faction color/shape, backup icons | Reads, never hardcodes, faction color and shape |
| Save/Load & Settings | IDs only | Stores IDs and runtime state, never definitions |
| Input System | Default bindings record | Bindings follow rules 2 and 8; Input owns the meaning of the bindings |

## Edge Cases

**Identity and aliases**
- **If two records share an ID**, in the same file, different files, or one is an alias of another: **error.** The report names both source locations. There is no override or "last one wins" rule in the base game; override behavior for mods is deferred.
- **If an alias equals a live record ID**: **error.** An alias can never shadow a real record.
- **If an alias points at another alias** (a chain): **error.** An alias must point directly at a live record, so `resolve_alias` is always one hop.
- **If a save file contains an ID that is neither live nor an alias**: `get` returns a not-found error and no fallback record is invented. Save/Load decides what the player sees; this system never guesses.
- **If an ID is malformed** (uppercase, spaces, non-ASCII, missing its type prefix, or longer than 64 characters): **error.**
- **If a data file cannot be read or does not parse**: **error** naming the file. No record from that file is loaded, and validation still runs over the other files so every problem is reported at once.

**References**
- **If a reference points at a missing ID**: **error.**
- **If a reference points at a record of the wrong type** (e.g. `move_ids` contains `char_…`, or a Character's `nation_id` names an `alien` faction): **error.**
- **If records form a reference cycle** (e.g. a Move whose effect triggers a Move that triggers the first): **error.** Cycle checking covers every reference an owning GDD does not explicitly declare as allowed to loop.
- **If a list field contains the same ID twice**: **error**, unless the owning GDD defines duplicates as meaningful.

**Structure**
- **If a required field is missing or has the wrong type**: **error.**
- **If a record has a field the schema does not define** (e.g. a typo such as `stat_blok`): **error.** Silently ignoring unknown fields hides typos, so the schema is strict.
- **If a required text field is empty or whitespace-only**: **error.** Optional text may be empty.
- **If an EffectDescriptor has an unknown `type`**: **error.**
- **If a `stat_block` or `reward` field is outside the range its owning GDD defines**: **error.**
- **If a type has zero records** (e.g. no Items at MVP): valid. A system that needs at least one record of a type reports that itself.

**Faction rules (from the art bible)**
- **If `signature_color`, `backup_icon_id` or `rule_id` is set on a `human_nation` faction, or `base_shape` does not match the faction's `kind`**: **error.**
- **If two alien factions share a `signature_color` or a `base_shape`**: **warning**, not error. The art bible gives every faction its own, but a fifth faction beyond the four base shapes is a design decision to make, not a crash.

**Other warnings** (reported, never blocking)
- A Character's `signature_move_id` also appears in its own `move_ids`, so it would be available from the start rather than unlocked.
- A record that nothing references (e.g. a QuirkState no Move or Combo uses).

**Lookup and load**
- **If any lookup happens before the catalog is Ready, or after it Failed**: an error is returned, never partial data.
- **If `all(type)` is called with an unknown type**: an error is returned, not an empty list.
- **If the catalog is Failed**: the player sees a plain-text error screen listing the first 20 errors and the log file location, never a crash or blank screen. The full list goes to the log.
- **If the same data is loaded twice in one session**: not supported; the catalog loads once at boot (Ready is terminal).

## Dependencies

**Upstream (this system depends on):** none. It is a Foundation system. The only external input is the data files themselves.

**Downstream (these systems depend on this one):**

| System | Dependency | Nature | What it needs |
|---|---|---|---|
| Game State & Scene Flow | Hard | Cannot leave boot until the catalog is Ready | Load status |
| Stats & Damage Resolution | Hard | Cannot compute anything without stat blocks | `stat_block`, `reward`, costs |
| Turn Battle System | Hard | Battles are built from Move, Character and Enemy records | Moves, combatants |
| Quirk State System | Hard | Its states are records here | QuirkState records |
| Combo System & Codex | Hard | Its combos are records here | Combo records |
| Faction Rule Modifiers | Hard | Rules attach to alien factions | Faction records, `rule_id` |
| Enemy AI | Hard | Reads each enemy's AI profile reference | `ai_profile_id` |
| Squad Roster & Recruitment | Hard | Recruits are Character records | Character records |
| Sprite & Camera Presentation | Hard | Needs asset IDs to find sprites and animations | `sprite_set_id`, `animation_id` |
| Dialogue, Banter & Quests | Hard | Needs speaker IDs; defines its own record types | Character IDs, rules 2–8 |
| Overworld Exploration & Encounters | Hard | Encounter tables reference enemies | Enemy IDs |
| Items, Equipment & Shops | Hard (Vertical Slice) | Items are records here | Item records |
| UI Framework | Hard | Names, icons, faction color and shape come from here | Display fields, faction visuals |
| Save/Load & Settings | Soft | Stores IDs only; works with any ID scheme but relies on stable IDs and aliases | IDs, `resolve_alias` |
| Input System | Soft | Its default bindings are a validated data record | Bindings record, rule 8 validation |

**Bidirectional contract.** Each downstream GDD must list *Content Data Definitions* in its own Dependencies section and name the fields it owns. That obligation is tracked in the systems index. Until a downstream GDD exists, its fields in the Core Rules table are provisional.

## Visual/Audio Requirements

None of its own. This is a data layer. It *stores* visual properties (faction `signature_color`, `base_shape`, `backup_icon_id`, and asset IDs for sprites, portraits, icons and animations), but how they look and sound is owned by the art bible, Sprite & Camera Presentation, UI Framework and Audio Manager.

## Game Feel

Not applicable. The player never operates this system directly.

## UI Requirements

One screen: the **content error screen**, shown only when the catalog is Failed.
- Plain text on a flat background, readable at 1280×720, navigable by keyboard and gamepad (Input System).
- Lists the first 20 errors in report order, one per line, with record ID, field and location, followed by the full log file path.
- No art, animation or faction styling, so it works even when the content that defines those visuals is what failed.
- One action: Quit.

> **📌 UX Flag — Content Data Definitions**: This system has one UI screen (the content error screen). In Pre-Production, run `/ux-design` for it before writing epics, or fold it into the UI Framework's spec.

## Cross-References

| This GDD references | Document | What is referenced |
|---|---|---|
| Coding standard: data-driven values | `.claude/docs/coding-standards.md` | "Gameplay values must be data-driven (external config), never hardcoded" (the reason this system exists) |
| Pillars 1, 3 and 4; MVP scope; moddability | `design/gdd/game-concept.md` | Joke and mechanic in one record; misfit roster; readable rules |
| Faction color, base shape, backup icon | `design/art/art-bible.md` §3 and §4 | Faction shape vocabulary (square / circle / wedge / star; organic for humans) and signature colors; "no information carried by color alone" |
| System list, layers, and the downstream systems this one serves | `design/gdd/systems-index.md` | Content Data Definitions is a Foundation-layer MVP bottleneck |
| Downstream field owners | Stats & Damage, Turn Battle, Quirk State, Combo & Codex, Faction Rule Modifiers, Enemy AI, Leveling & Loyalty, Items (GDDs not yet written) | Each will own the meaning of the fields assigned to it in Core Rules rule 1 |

## Acceptance Criteria

Criteria come from Detailed Design and Edge Cases (this system has no Formulas section). "Error" and "warning" below mean a structured validation entry with fields `severity`, `record_id`, `field` (where applicable) and `location` (file path plus record index). Tests assert on those fields, never on message wording. Fixtures are files under the test root, never inline data.

Evidence type: **[L]** Logic (automated gdUnit4 test under `tests/unit/content_data/`), **[I]** Integration, **[UI]** retained screenshot in `production/qa/evidence/`, **[P]** performance benchmark output.

**Loading and lookup**
- **AC-1 [L]** GIVEN the fixture `valid_one_of_each` (one record of each of the 7 types, including list fields and nested EffectDescriptors), WHEN the catalog loads, THEN the state is Ready and `get(type, id)` returns every record with every field deep-equal to the fixture.
- **AC-2 [L]** GIVEN a Ready catalog, WHEN `all(type)` is called on each type, THEN records come back sorted by ID, and the result is identical when the same files are loaded in a shuffled file order.
- **AC-3 [L]** GIVEN a fixture with zero records of every type, WHEN it loads, THEN the state is Ready and `all(type)` returns an empty list for each type.
- **AC-4 [L]** GIVEN a Ready catalog, WHEN `get` is called with a missing ID, THEN it returns a not-found result and no record. WHEN `all` is called with an unknown type, THEN it returns an error, not an empty list.
- **AC-5 [L]** GIVEN a Ready catalog, WHEN a caller modifies a returned definition (including a nested list and a nested EffectDescriptor), THEN the next `get` for that ID returns the original values.

**States**
- **AC-6 [L]** GIVEN a catalog in Unloaded, Loading or Validating, WHEN any lookup is called, THEN it returns an error.
- **AC-7 [L]** GIVEN a catalog that is Ready, or one that is Failed, WHEN a second load is requested, THEN the request returns an error and the state is unchanged.
- **AC-8 [L]** GIVEN a fixture with exactly one error, WHEN it loads, THEN the state is Failed and every lookup returns an error, including for records that were themselves valid.

**Identity and aliases**
- **AC-9 [L]** One test per defect: an ID with uppercase letters, one with a space, one without its type prefix, and one of 65 characters each produce an error whose `record_id` is the offending ID. An ID of exactly 64 characters loads.
- **AC-10 [L]** GIVEN two records with the same ID in two different files, WHEN validating, THEN one error lists both locations.
- **AC-11 [L]** GIVEN `char_new` with `aliases: [char_old]`, WHEN `resolve_alias("char_old")` is called, THEN it returns `char_new`.
- **AC-12 [L]** One test each: an alias equal to a live ID, an alias that points to another alias, and an alias whose record is missing each produce an error.

**References**
- **AC-13 [L]** One test each: a reference to a missing ID; a wrong-type reference (`move_ids` containing a `char_` ID, and a Character `nation_id` naming an `alien` faction); a self-reference; a 2-record cycle; a 3-record cycle; and a duplicate entry in a list field. Each produces an error.

**Structure and content**
- **AC-14 [L]** One test each: an unknown field, a missing required field, a wrong-typed required field, an empty required text field, a whitespace-only required text field, and an unknown EffectDescriptor `type`. Each produces an error naming the record and field.
- **AC-26 [L]** One test per boundary: `stat_block.max_hp` 0 and 1000, `max_mp` −1 and 100, `attack`/`defense`/`speed` 0 (or −1 for `defense`) and 100, `Move.cost` −1, `reward.xp` −1 and 10000, `reward.money` −1 and 10000. Each produces an error naming the record and field. The matching minimum and maximum values each load.
- **AC-15 [L]** GIVEN a Move whose effects use only known descriptor types, WHEN loaded, THEN `get` returns the descriptors deep-equal to the fixture and loading triggers no game effect.
- **AC-16 [L]** GIVEN one data file that does not parse alongside valid files, WHEN loading, THEN there is one error naming that file, the state is Failed, and errors in the other files are still reported.

**Faction rules and warnings**
- **AC-17 [L]** One test each: `signature_color` on a `human_nation`, and a `base_shape` that does not match `kind`. Each produces an error.
- **AC-18 [L]** One test each: two alien factions sharing `signature_color`, two sharing `base_shape`, a Character whose `signature_move_id` is also in its `move_ids`, and a record nothing references. Each produces a warning entry, and the state is Ready.
- **AC-19 [L]** GIVEN a fixture with 2 errors and 2 warnings, WHEN validating, THEN the state is Failed and the report contains all 4 entries with the correct severities.

**Reporting**
- **AC-20 [L]** GIVEN a fixture triggering 5 different rules (malformed ID, duplicate ID, missing reference, unknown field, faction mismatch), WHEN validating, THEN the report has 5 errors, and their order is identical across repeated runs.
- **AC-21 [L]** GIVEN 30 errors, WHEN the error-screen text is built, THEN it contains exactly the first 20 errors in report order and the log file path, and the log contains all 30.
- **AC-22 [UI]** GIVEN a data set with 30 errors, WHEN the game is launched, THEN the player sees the plain-text error screen (no crash, no blank screen). Evidence: retained screenshot.
- **AC-23 [I]** GIVEN a catalog that ends Failed, WHEN the game boots, THEN Game State & Scene Flow remains in its boot state and never enters the overworld or battle state.
- **AC-24 [I]** GIVEN the standalone headless validation check, WHEN run on valid data (warnings allowed), THEN it exits with code 0. WHEN run on data with any error, THEN it exits with code 1 and prints the full report.

**Performance**
- **AC-25 [P]** GIVEN a generated catalog of 500 valid records, WHEN it is loaded and validated (file reading and validation, excluding engine startup) on the development PC, THEN the median of 10 runs is under 1 second. Run as a benchmark, not as a unit test. *Provisional: the target hardware is an Open Question.*

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Storage format and loader**: Godot `Resource` files, JSON, or something else? Affects authoring speed and future mod support. | `/architecture-decision` (godot-specialist) | Before the first Content Data story (Technical Setup) |
| 2 | **Localization**: are player-visible strings ever translated? If so, do records hold string keys instead of inline text? | user + localization-lead | Before Alpha |
| 3 | **Mod content policy**: override rules for duplicate IDs, and whether invalid modded records are skipped rather than blocking boot. | user | When post-launch mod support is scheduled |
| 4 | **Target hardware** for the AC-25 load-time budget (currently "the development PC"). | user + performance-analyst | Before Vertical Slice |
| 5 | **Provisional fields**: `stat_block`, `Move.cost` and `reward` are no longer provisional — Stats & Damage Resolution (Designed 2026-10-20) fixed their meaning and ranges (see rule 8 and Edge Cases). Still provisional: move `target_type` and semantics, quirk and combo rules, faction rules, AI profiles — each may change when its owning GDD is designed. | each remaining downstream GDD | As each remaining GDD is approved |
