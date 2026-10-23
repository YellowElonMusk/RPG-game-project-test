# ADR-0013: Localization — English Source Text Everywhere, Gettext Catalogs with Derived Contexts, Mechanical Extraction

## Status
Accepted

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
- **User**: autonomous mode, with decisions logged in `production/session-logs/decision-log.md`. The architecture half of Content Data GDD Open Question 2 was answered autonomously and logged for user veto. Whether, and into which locales, the game is translated stays the user's call.
- **Claude**: orchestrating session.
- **Reviewers**: godot-specialist (engine validation, probed on 4.7.2), technical-director (TD-ADR) and localization-lead (Review History).

Revision 2 folds in both reviews.

## Summary
The Content Data GDD (Rule 6, TR-content-012) requires player-visible strings to be plain-text record fields, extractable mechanically. Its Open Question 2 is due before Alpha. Proposed ADRs had started making their own string choices (ADR-0008 §11, ADR-0011's record templates), so without a decision three conventions would ship.

Decided:
- **Source text.** English is the source text everywhere: record fields, scene text, code. Records stay a writing task, and anything untranslated falls back to readable English.
- **Catalogs.** If the game is translated, it uses gettext catalogs: a `.pot` template and one `.po` per locale.
- **Contexts.** Each string's context is derived from where it lives:
  - `<record_id>.<field>[.<key>]` for records;
  - an explicit `<screen>.<purpose>` for code;
  - `Control.translation_context` for scene labels that need one.
- **Lookup.** Records are read through a leaf utility, `LocText`. Code calls `tr()`.
- **Tooling.** Project GDScript tools do all extraction and checking, headlessly, because Godot's POT generation is editor-only (probed).
- **Boot validation.** A registered validator makes every record declare which of its string fields are translatable.
- **Not decided here.** The locale list is left to the user.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (TranslationServer) + UI |
| **Layer** | Presentation (the `LocText` helper is a leaf utility usable from any layer, §3) |
| **Knowledge Risk** | MEDIUM. Post-cutoff changes: live translation preview (4.5), CSV plurals and context (4.6), `OptimizedTranslation.generate()` returning `bool` (4.7). The gettext loader and `tr()` were probed on 4.7.2 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.6 Localization row, 4.7 `OptimizedTranslation` row), `modules/ui.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None required at runtime. `Control.translation_context` (StringName) is used for per-node scene context. Probed present; its introduction version is not in the engine reference |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22):**<br>(1) **Lookups.** `TranslationServer.translate(msg, ctx)` and `Object.tr(msg, ctx)` return the `.po` entry for `msgctxt` + `msgid`. A wrong or missing context falls back to the English source. **PROBED**.<br>(1b) **Fuzzy entries are ignored**, and the English source is returned instead. This holds when `#, fuzzy` is placed correctly; `msgmerge` always places it correctly. **PROBED**.<br>(1c) **Plurals.** `tr_n()` with context selects the right plural forms. **PROBED**.<br>(2) **Import.** A `.po` file listed in `internationalization/locale/translations` imports as a Translation on `--import`, and `get_loaded_locales()` reports it. **PROBED**. Export baking into the PCK is **REASONED** (standard mechanism).<br>(3) **POT generation is editor-GUI-only.** No `--generate-pot` CLI flag exists on 4.7.2. **PROBED**. Hence §2's own extractors.<br>(4) **Scene context.** `Node.auto_translate_mode` exists (DISABLED/INHERIT/ALWAYS), and **`Control.translation_context` (StringName) exists**. **PROBED**.<br>(5) **Pseudolocalization.** The settings and `--editor-pseudolocalization` exist. **PROBED**. The size of text expansion is not probed.<br>(6) `NOTIFICATION_TRANSLATION_CHANGED` arrives synchronously, once per `set_locale()`. **PROBED** (godot-specialist, `/architecture-review` 2026-10-22b F5).<br>(7) `tr(&"Open", &"menu.open")`, the StringName literal form, works. **PROBED** (same review, F5).<br>(9) **Double translation.** A `Control` with the default `auto_translate_mode` re-translates text that code already passed through `tr()` or `LocText`: `tr("Hello")` gives "Bonjour", and the label then looks "Bonjour" up as a new source string. Under pseudolocalization the brackets apply twice (`[[Ṕłáý]]`). **PROBED** (same review, F4). Hence §1's rule for code-set text.<br>**Still to verify:**<br>(8) An exported build loads the `.po` translations |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Content Data, **Accepted**): records with stable IDs and plain-text fields; aliases. **ADR-0004** (Content Boot Ordering, **Accepted**): `register_record_validator()` for the `LOC_FIELDS` validator; `ContentBootstrap.run()` for the record extractor |
| **Enables** | **ADR-0008** (UI Framework): its §11 is resolved by this ADR, rewritten in place; ADR-0008 lists this ADR under Depends On. **ADR-0011** (Faction Rule Modifiers): `FactionRuleData.texts` and the fallback rule's `tr()` sentences; ADR-0011 lists this ADR under Depends On. **ADR-0009** (Save/Load & Settings): the `locale` setting. Any writing or translation pass |
| **Blocks** | Shipping any non-English locale. No MVP story is blocked; MVP ships English. This ADR fixes the conventions code must follow from now on |
| **Ordering Note** | **Revises ADR-0008 §11 (Proposed), in place**: UI strings are English source text with an explicit context. **Answers the architecture half of Content Data GDD Open Question 2**: records keep inline English text, with no keys. Mark it resolved in the GDD on acceptance; whether and which locales stays open. **Adds one line to ADR-0004 §1's registrant list**: the `LocFieldsValidator` registration. On acceptance, `architecture.md` Required ADRs item 7 is closed |

## Context

### Problem Statement
The game is comedy. Pillar 1 puts the punchline, the rule text and the effect in one record. Translating jokes is the most expensive and fragile part of localizing a comedy RPG, so the pipeline has to:
- keep the writer's source text in the record;
- give translators context to adapt rather than transliterate;
- keep stale translations off screen when the source changes;
- never show a key to the player.

Code today hardcodes English (the battle HUD, the rule classes, the chapter demo). Every UI story from here on writes strings, so the convention has to be fixed now. The locale list can wait.

### Constraints
- **Content Data rules.** Rule 6: text is plain-text record fields. Rule 2: IDs are permanent, and renames go through aliases.
- **Records are `.tres` catalog records** (ADR-0001), not scenes.
- **Godot's POT generation is editor-only** (probed), so CI can't use it.
- **No locale list exists.** That is a business decision, and MVP is English-only (game brief).
- **The UI is 640×360 logical with a text scale up to 1.5** (ADR-0008).
- **Solo developer.** The pipeline should be tooling, not process.

### Requirements
- TR-content-012: record strings extractable mechanically.
- One convention covering records, scenes and code.
- A missing or stale translation shows the English source, never a key.
- Placeholders and plurals survive translation, checked by a tool.
- The locale can be switched live.

## Decision

**1. English source text everywhere. Context is derived, never invented.**
- **Records.** Text fields stay in plain English. The context of a record string is `<record_id>.<field>`, plus `.<key>` for dictionary fields (`move_late_fee.display_name`, `rule_bureaucratia_permit.texts.banner_locked`).
  - Contexts are stable while the record's **live ID** is unchanged. A rename or merge (ADR-0001 aliases) gives the record a new live ID and therefore new contexts. Its old translations become obsolete and the game falls back to English, which is safe but loses work.
  - `extract_records.gd` therefore emits an **alias → live-ID context remap** (`loc/context_remap.csv`). The `tools/loc/apply_remap.gd` migration rewrites `msgctxt` in every `.po`, so translations follow a rename.
  - Renaming a **field** orphans every translation of that field. Treat it as a schema migration and run the same remap.
- **Code.** Code uses `tr("Source text", &"<screen>.<purpose>")`, and `tr_n(singular, plural, n, &"ctx")` where it shows a count. The context is never empty.
- **Scenes.** Fixed labels use automatic translation. A label whose English is ambiguous, and every joke, gets `translation_context` set on the node in the inspector (probed present), or is set from code with a context.
- **Each control is translated exactly once.** A control is either auto-translated (its text is the fixed English from the scene) or **code-set**, never both. A code-set control (any `Control` whose displayed text code assigns from `tr()`, `tr_n()`, `LocText` or a formatted string) **must** have `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`, set in its scene or before its first text assignment. Otherwise the control translates the already-translated string again (Verification item 9). A record value, a translated sentence or a pseudolocalized string would then be looked up a second time, and pseudolocalization screenshots (§6) would show doubled brackets. ADR-0008's widgets that take text from code (`LocText` labels, `PromptGlyph` captions, damage numbers, `ReplayIndicator`) set it in their own `_init()`. **DISABLED goes on the leaf control that shows the code-set text, never on a container:** `INHERIT` children of a DISABLED node stop translating too, including fixed labels and `tooltip_text` (probed, `/architecture-review` 2026-10-22c E6). A fixed child under a code-set widget sets `AUTO_TRANSLATE_MODE_ALWAYS`. A value saved in the `.tscn` overrides an `_init()` assignment.
- **Placeholders.** Placeholders are named (`{name}`) and filled with `String.format()` after translation. `%s` and display-text concatenation are forbidden.

**2. Catalogs and extraction (all headless GDScript).**
- **`loc/game.pot`** is written by `tools/loc/extract.gd`, which merges three extractors in GDScript, so neither gettext nor the editor is needed in CI:
  - **Records**, via `extract_records.gd`, which runs `ContentBootstrap.run()` as `validate-content.gd` does (ADR-0004). It walks each record's `LOC_FIELDS` (§4) and writes `msgctxt "<id>.<field>[.<key>]"` and `msgid "<English>"`, with a translator comment carrying the record type and any author note.
  - **Code**, via `extract_code.gd`. It scans `src/**/*.gd` for `tr(` and `tr_n(` calls whose arguments are string literals, accepting both `"ctx"` and `&"ctx"`. A non-literal or missing context fails the tool.
  - **Scenes**, via `extract_scenes.gd`. It loads every `.tscn` under `scenes/` and `src/` headlessly and records each auto-translated `Control`'s text with its `translation_context`.
- **`loc/<locale>.po`** holds one locale each, maintained by translators with standard gettext tools (`msgmerge`). A changed English source becomes *fuzzy*, and Godot ignores fuzzy entries (probed), so the player sees the new English instead of a stale joke. gettext is a **translator** dependency only, never a CI or player dependency.
- **Plurals** use gettext's per-locale plural forms (probed with context). The 4.6 CSV path isn't used: it has no fuzzy mechanism.
- **Registration.** `.po` files are listed in `internationalization/locale/translations` (probed: they import on `--import`).

**3. Runtime lookup: `LocText`, a leaf utility.**

```gdscript
## src/loc/loc_text.gd — leaf utility: depends only on TranslationServer and duck-typed record.id
class_name LocText
static func of(record: Resource, field: StringName) -> String
static func of_key(record: Resource, field: StringName, key: String) -> String
static func fmt(text: String, args: Dictionary) -> String
```

- **`of()`** calls `TranslationServer.translate(record.get(field), "%s.%s" % [record.id, field])`. With no translation, it returns the English value.
- **A leaf utility.** `src/loc/` imports nothing from any layer, so Feature code (ADR-0011's rules) and Presentation code may both call it without breaking Principle 7.
- **Display code** **must** use `LocText`, never the raw field, whenever it shows record text. Logic, logs and IDs use the raw fields.

**4. Every record declares which strings are text: a boot-time validator.**
- **Two lists per record script.** Each record script with any `String`, `PackedStringArray` or `Dictionary` export declares two constants:
  - `const LOC_FIELDS: Array[StringName]`, the translatable text;
  - `const NON_LOC_FIELDS: Array[StringName]`, the IDs, asset IDs, hex colours and paths.
  
  Constants are not properties, so ADR-0001's unknown-field check ignores them (TD-verified).
- **`LocFieldsValidator`** (`src/loc/loc_fields_validator.gd`, pure) is registered through `register_record_validator()` for every record type, from `ContentBootstrap.run()`. It runs on every boot and in `validate-content.gd`. It checks two things:
  - every string-typed export appears in **exactly one** list;
  - every `LOC_FIELDS` value has balanced `{placeholder}` braces.
- So a new text field can't be forgotten, and a non-text field can't be shipped to translators by accident.

**5. Checks (`tools/loc/check_loc.gd`, headless, CI).**
- **Placeholders.** Every `{name}` in a source string appears in each non-fuzzy translation, and the translation adds no new ones.
- **Plurals.** Every plural entry has all of its locale's forms.
- **Hygiene.**
  - Every `.po` `msgctxt` exists in `game.pot`; obsolete entries are reported.
  - `project.yaml` `localization.locales` matches `internationalization/locale/translations`.
- **Coverage report.** A report, not a failure, lists untranslated and fuzzy entries per locale. Shipping a locale needs zero of either. That is a release-checklist gate.

**6. Pseudolocalization screenshots (windowed, not headless).** A headless run has no renderer, so it can't capture frames. Pseudolocalized screenshots are taken by a **windowed** run, following `.claude/docs/run-and-observe.md`: locally, or on a CI runner with a GPU or virtual display. It uses about 40% expansion, accents and brackets, at 640×360 and text scale 1.5. The screenshots are retained in `production/qa/evidence/` as part of each UI story's evidence. They catch clipped text before any translator is hired.

**7. Locale selection.**
- **Authoring record.** `project.yaml` `localization.locales` (currently `[en]`) is the record of shipped locales. Adding one is a business decision.
- **At runtime.** `project.yaml` isn't exported, so the runtime list is `TranslationServer.get_loaded_locales()` plus `en`, the source.
- **At boot.** `GameRoot` applies ADR-0009's `locale` setting with `TranslationServer.set_locale()` before Title. An empty setting means the best match for `OS.get_locale_language()` among the loaded locales, else `en`.
- **On a change** in settings, the new locale applies live. Auto-translated controls update; code-set text re-applies on `NOTIFICATION_TRANSLATION_CHANGED` (ADR-0008 §11). That notification is verification item 6.
- **Fonts.** A locale the theme fonts don't cover adds a fallback font to `ui_theme.tres`. RTL and CJK each get an amendment when needed.

**8. Never translated.**
- IDs, logs, and validation/Content Error text (developer-facing).
- Keyboard key labels, which come from the OS layout (ADR-0008).
- Save files, which hold IDs (ADR-0009), so a save loads in any locale.

**9. What translators get with every string.** The localization-lead review requires these before Alpha.
- **Length limits.** A record script may declare `const MAX_LENGTHS: Dictionary = {&"display_name": 18}` (characters, at text scale 1.0). Code calls that display into a fixed slot pass the limit through an extractor comment (`# loc:max=18`). `extract.gd` writes each limit into the `.pot` as a translator comment, and `check_loc.gd` fails a translation that exceeds it. The pseudolocalization screenshots (§6) catch whatever the limits miss.
- **Templates are written grammatically neutral.**
  - `String.format()` cannot do gender or case agreement. Templates that insert a name or noun are therefore written so that no word has to agree with the inserted value: "Complained status applied to {name}", not "{name} was Complained".
  - `LocFieldsValidator` can't enforce this; it is a writing rule, checked in content review.
  - If a funded locale needs real agreement, an ICU-style `select` helper is a later amendment to `LocText`.
- **Author notes are mandatory for comedy.**
  - Every `LOC_FIELDS` text on joke-bearing types (QuirkState `description`/`rule_text`, Combo `punchline_text`/`codex_text`, Move `flavor_text`, `FactionRuleData.texts`) has an author-note companion field (`loc_note`) saying what the joke is, its target and tone, and whether to adapt or translate.
  - Records keep the note as a `NON_LOC_FIELDS` field.
  - `extract_records.gd` emits it as a translator comment.
  - `check_loc.gd` warns when it is empty.
- **Glossary.** `loc/glossary.md` lists every recurring proper noun and term: faction names, quirk names, combo names, characters' nicknames. Each entry carries its source record ID and its approved translation per locale. Consistency across the many records that *mention* a term is a manual check at the release-checklist gate, next to the coverage report.
- **Screenshots for translators.** When a locale is funded, each UI screen's English screenshot (already retained as UI evidence) is handed to translators along with the `.pot`.

**Explicitly deferred until a locale needs it:**
- **Regional fallback chains** (`fr_CA → fr → en`). `project.yaml` gains a chain before any regional variant ships.
- **Locale-aware number and currency formatting** (a `LocNumber` helper). MVP shows bare integers.
- **RTL.** It needs both font support (this ADR) and UI mirroring, bidi and scrollbar flips (ADR-0008), so it is an amendment to both.

### Architecture Diagram

```
 authoring (English)                       extraction (headless GDScript, CI)            runtime
 data/**/*.tres  LOC_FIELDS ── extract_records.gd ─┐ (ContentBootstrap.run)          LocText.of(record, field)
 src/**/*.gd  tr("…", &"ctx") ── extract_code.gd ──┼─► extract.gd ─► loc/game.pot      └ TranslationServer.translate(
 scenes/**/*.tscn auto-translate + translation_context ── extract_scenes.gd ─┘              english, "<id>.<field>")
                                                     │       msgmerge (translators) ─► loc/<locale>.po
 boot: LocFieldsValidator (every string export in LOC_FIELDS xor NON_LOC_FIELDS)      fallback: English (also for fuzzy)
 check_loc.gd: placeholders · plurals · obsolete msgctxt · locales vs project.yaml · coverage report
 extract_records.gd ─► loc/context_remap.csv (alias → live ID) ─► apply_remap.gd on .po
 settings.locale ─► set_locale() among get_loaded_locales()+en ─► NOTIFICATION_TRANSLATION_CHANGED
 windowed pseudolocale run ─► retained screenshots (640×360, text scale 1.5)
```

### Key Interfaces

```gdscript
## src/loc/loc_text.gd — leaf utility
class_name LocText
static func of(record: Resource, field: StringName) -> String
static func of_key(record: Resource, field: StringName, key: String) -> String
static func fmt(text: String, args: Dictionary) -> String

## src/loc/loc_fields_validator.gd — pure; registered for every record type via ContentBootstrap (ADR-0004 §1)
class_name LocFieldsValidator
static func validate(record: Resource) -> PackedStringArray

## On every record script with string-typed exports (ADR-0001 records)
const LOC_FIELDS: Array[StringName] = [&"display_name", &"description"]   # translatable
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"sprite_set_id"]       # everything else string-typed

## tools/loc/extract.gd (+ extract_records.gd, extract_code.gd, extract_scenes.gd) → loc/game.pot, loc/context_remap.csv
## tools/loc/check_loc.gd   — placeholders, plurals, obsolete msgctxt, locale list, coverage
## tools/loc/apply_remap.gd — rewrites msgctxt in .po after record renames
## project.yaml
# localization:
#   locales: [en]
#   source_locale: en
```

### Implementation Guidelines
- Player-visible text **must** be English source text. Where it lives:
  - In records, it **must** be in a field listed in `LOC_FIELDS`.
  - In code, it **must** go through `tr()` or `tr_n()` with a literal, non-empty context.
  - In scenes, it **must** use automatic translation, with `translation_context` set wherever the English is ambiguous or the string is a joke.
- A control whose text code sets **must** have `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`. A control is auto-translated or code-set, never both (§1).
- Every string-typed record export **must** be listed in exactly one of `LOC_FIELDS` or `NON_LOC_FIELDS`.
- Display code **must** read record text through `LocText`.
- Translatable text **must** use named `{placeholders}`. `%s` and display-text concatenation **are forbidden**.
- Code **must never** show a key, and **must never** invent a context outside the two schemes in §1.
- Screens that set text in code **must** re-apply it on `NOTIFICATION_TRANSLATION_CHANGED`.
- Logs, IDs, validation errors and the Content Error screen **must not** be translated.
- A record rename or field rename **must** be followed by `apply_remap.gd` on every `.po`.

## Alternatives Considered

### Alternative 1: String keys in records with a CSV table
- **Description**: Records hold keys, and all English lives in `translations.csv`.
- **Pros**: The classic Godot CSV workflow, with plurals and context since 4.6.
- **Cons**:
  - The writer authors the joke away from its record, which breaks Pillar 1 and "content is a writing task".
  - A missing entry shows a key.
  - A source edit doesn't flag stale translations.
- **Rejection Reason**: Costs the authoring model the GDD protects, and fails the "never a key" requirement.

### Alternative 2: Keys in code, source text in records
- **Description**: ADR-0008's first-draft rule.
- **Pros**: Short code strings.
- **Cons**: Two conventions, and a missing entry shows a key.
- **Rejection Reason**: One convention covers both and falls back to English.

### Alternative 3: CSV (4.6+) instead of `.po`
- **Description**: Godot's native CSV import with plural and context columns.
- **Pros**: No gettext tooling; edits in a spreadsheet.
- **Cons**: No fuzzy marking, no standard merge tool, and vendors expect `.po`.
- **Rejection Reason**: Fuzzy entries are what keep stale jokes off screen (probed).

### Alternative 4: The editor's POT generation for code and scenes
- **Description**: Use Godot's built-in POT generator.
- **Pros**: No custom extractor.
- **Cons**: It is editor-GUI-only on 4.7.2 (probed), so CI can't run it.
- **Rejection Reason**: Headless GDScript extractors run in CI and also cover records.

### Alternative 5: Defer every localization decision
- **Description**: Ship hardcoded English, and decide later.
- **Pros**: No work now.
- **Cons**: Every UI story would hardcode strings its own way, and three conventions already exist in Proposed ADRs.
- **Rejection Reason**: The convention is nearly free now and expensive later. Only the locale choice is deferred.

## Consequences

### Positive
- Writers keep authoring jokes in the record, in English.
- No key ever reaches the player, and neither does a stale translation: a missing or fuzzy entry shows English.
- Every string export is classified at boot, so text can't be forgotten or leaked to translators.
- Extraction and checks run headlessly in CI, with no gettext or editor dependency.
- Pseudolocalization screenshots catch overflow at 640×360 from the first UI story.

### Negative
- Display code must use `LocText`; enforced by review and a grep.
- Every record script declares two lists.
- Three small extractors to maintain, because POT generation is editor-only.
- Renames need a context remap to keep their translations.
- Identical English in different contexts become separate entries. That is correct for comedy, but it means more entries.

## Risks
- **`&"ctx"` StringName literals** behave differently from strings in `tr()` (item 7). *Mitigation:* probe it with the first UI story. If it fails, the convention switches to plain string literals, which `extract_code.gd` already accepts.
- **The scene extractor misses dynamic text.** *Mitigation:* dynamic text is set from code, so `extract_code.gd` covers it.
- **Comedy doesn't survive translation.** *Mitigation:* translator comments, and a localization-lead review before a locale ships. That is process, outside architecture.
- **Text expansion overflows the 640×360 UI.** *Mitigation:* windowed pseudolocalization screenshots from the first UI story.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| content-data-definitions.md | TR-content-012 / Rule 6: player-visible strings are plain-text record fields, extractable mechanically | §1 English fields with derived contexts; §2 `extract_records.gd`; §4 `LOC_FIELDS` validator |
| content-data-definitions.md | Open Question 2: do records hold keys? (architecture half) | Records keep inline English, with no keys. **Whether and which locales are translated stays the user's call.** If translated: gettext. Logged for user veto |
| content-data-definitions.md | Rule 2: IDs permanent; renames via aliases | §1 contexts from live IDs, with an alias remap |
| sprite-camera-presentation.md / ADR-0008 | Readable UI at every text scale | §6 pseudolocalization screenshots |
| input-system.md | Prompts show the user's own key labels | §8 OS layout labels, untranslated |

## Performance Implications
- **CPU:** one lookup per displayed string, when it is set, not per frame. One validator call per record at boot.
- **Memory:** one translation per loaded locale.
- **Load Time:** `.po` files are baked at export; a locale switch is immediate.

## Migration Plan
1. **Now (convention):**
   - `LocText`, `LocFieldsValidator`, and `LOC_FIELDS`/`NON_LOC_FIELDS` on the record scripts, with ADR-0001's record migration.
   - The ADR-0004 §1 registration line.
   - ADR-0008 §11 rewritten (done).
2. **With the first UI story:**
   - Probe items 6–8.
   - Take windowed pseudolocalization screenshots as part of its evidence.
3. **With the battle HUD migration (ADR-0008 step 4):** hardcoded HUD strings, and the rule classes' sentences via ADR-0011's record `texts` and fallback `tr()`.
4. **Before Alpha:**
   - The extractors, `check_loc.gd` and `apply_remap.gd` in CI.
   - The `project.yaml` `localization` block.
   - Content Data GDD Open Question 2 marked resolved (architecture half).
   - A localization-lead review of this ADR.
5. **When a locale is funded:**
   - Add it to `project.yaml`.
   - Create `loc/<locale>.po` and add any font fallbacks.
   - Run a translator review pass.

## Validation Criteria
- **Unit (`LocText`):**
  - `LocText.of()` returns the translation under a test locale.
  - It returns the English source when the entry is missing or fuzzy.
  - `fmt()` fills named placeholders.
- **Unit (`LocFieldsValidator`):** fails a record with a string export in neither list, or in both.
- **CI (extractors):**
  - `extract_code.gd` fails on a `tr()` with no context or a non-literal context.
  - `check_loc.gd` fails on a translation missing `{rounds}`, and on a locale mismatch with `project.yaml`.
- **Integration:** switching locale at runtime updates an auto-translated `Label` and a code-set `Label` on the same screen (windowed).
- **Integration (single translation):** under a test locale whose catalog also maps the translated string to a sentinel (for example "Bonjour" → "DOUBLE"), a code-set `Label` shows the translation, never the sentinel. Under pseudolocalization its text carries exactly one bracket pair.
- **Screenshot:** pseudolocalized Title and battle HUD at 640×360 and text scale 1.5, with no clipped text, retained in `production/qa/evidence/`.
- **Grep:**
  - no `tr(` without a context in `src/`;
  - no `%s` in translatable strings;
  - no `.display_name` read for display outside `LocText`;
  - no `.text =` assignment of a `tr(`, `tr_n(` or `LocText` result in a script whose control is not set to `AUTO_TRANSLATE_MODE_DISABLED` (review check; the integration test above is the hard gate).

## Related
- **Depends on:** `adr-0001-content-data-storage-format.md`, `adr-0004-content-boot-ordering.md` (one registrant line).
- **Revises (Proposed):** `adr-0008-ui-framework.md` §11.
- **Consistent with:**
  - `adr-0011-faction-rule-modifiers.md` (record `texts`; fallback `tr()` sentences);
  - `adr-0009-save-load-settings.md` (the `locale` setting; saves hold IDs).
- **GDDs:** `design/gdd/content-data-definitions.md` (Rule 6, Open Question 2).
- **On acceptance:**
  - `architecture.md` Required ADRs item 7 is closed.
  - Register `LocText` and the `LOC_FIELDS` convention in `docs/registry/architecture.yaml`.

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | **4 blocking, fixed:**<br>- Runtime locale list from `project.yaml`. Fixed: `get_loaded_locales()` plus `en`, with a `check_loc` consistency check.<br>- Core engine assumptions unverified. Fixed: fuzzy, POT generation and StringName context added and probed.<br>- How to find text fields not in `LOC_FIELDS` was undefined. Fixed: `LOC_FIELDS`/`NON_LOC_FIELDS` plus a registered boot validator.<br>- Headless screenshots. Fixed: windowed per run-and-observe.<br>**Advisories folded in:** alias/field-rename context remap; no gettext in CI (GDScript merge); `src/loc` as a leaf utility; the Open Question 2 answer limited to its architecture half; cascade fixes (ADR-0008 Enables, ADR-0011 fallback `tr()`); scene-context rule |
| 2026-10-22 | godot-specialist | APPROVE WITH NOTES | **Probed:** `msgctxt` lookup and fallback; fuzzy entries ignored; plurals with context; `.po` import; POT generation is editor-only (no CLI); `auto_translate_mode` and `Control.translation_context` exist; pseudolocalization settings exist |
| 2026-10-22 | localization-lead | APPROVE WITH NOTES → revised | **4 blocking (pre-Alpha), folded into §9:** length metadata in the `.pot` with a `check_loc` limit; grammatically neutral templates (no agreement via `String.format`); mandatory `loc_note` on joke-bearing fields; `loc/glossary.md` checked at release. **Advisories:** translator screenshots added; fallback chains, number formatting and RTL (font plus ADR-0008 mirroring) explicitly deferred. Nothing blocks the English-only MVP |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22b.md`) | CONCERNS → fixed | godot-specialist **F4** (blocking): code-set text is translated twice by default `auto_translate_mode`. Fixed: §1 "Each control is translated exactly once", an Implementation Guideline, a single-translation integration test and a review grep. **F5**: Verification items 6 and 7 are now PROBED; item 9 records F4. ADR-0008 and ADR-0011 now list this ADR under Depends On |
| 2026-10-22 | User | **Accepted** | Explicit instruction to fix the review findings, then accept ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010. Dependencies ADR-0001 and ADR-0004 are Accepted. No story was Blocked on this ADR. The additive registrant line for ADR-0004 §1 is annotated there. **Follow-ups not done in this step:** mark the architecture half of Content Data GDD Open Question 2 resolved; register `LocText` and `LOC_FIELDS` in `docs/registry/architecture.yaml`; close `architecture.md` Required ADRs item 7 |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22c.md`) | PASS → note added | godot-specialist **E6**: DISABLED is inherited by `INHERIT` children (fixed labels, tooltips). §1 now puts DISABLED on the leaf control only, with `ALWAYS` for fixed children |
