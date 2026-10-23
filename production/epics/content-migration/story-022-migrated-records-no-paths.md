# Story 022: No migrated record names a file path: every cross-reference is a record ID and every asset field is an asset ID

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Implementation Guidelines: "a direct Resource reference would violate Rule 3 and reintroduce file-path coupling through Godot's own `.tres` `ExtResource` mechanism")
**ADR Decision Summary**: Records reference other records by ID and assets by asset ID, never by path; a `.tres` record's only external resource is its own script.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The scan reads `res://` `.tres` text files with `FileAccess`. In an exported build they are binary, so this is a source-tree (CI) test only. Godot 4.4+ writes `uid=` attributes on `ext_resource` lines.

**Control Manifest Rules (this layer)**:
- Required: "Cross-references are `String` / `PackedStringArray` fields holding record IDs."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference."
- Guardrail: none (CI-only scan).

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Implementation Guidelines, scoped to this story:*

- [ ] GIVEN every `.tres` under `data/factions/`, `data/enemies/`, `data/moves/` and `data/faction_rules/` (and `data/characters/` if story 019 lands), WHEN the test scans each file, THEN no quoted String/StringName value in a property line matches `(?i)(res|user|uid)://` or `(?i)\.(tres|res|tscn|scn|gd|gdshader|png|jpe?g|webp|svg|ogg|wav|mp3|json|ttf|otf)\b`; the file has exactly one `[ext_resource` line, `type="Script"`, with its path under `res://src/data/records/`; and it has no `[sub_resource` section unless its script is in the record-script allowlist.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines and the QA gate (RC-7):*

- **Pinned regexes (RC-7).** The extension check only looks inside quoted string values on property lines, so `low_hp_threshold = 0.5` and sentence-final periods in banner text don't trip it. Compile both patterns with `RegEx` once.
- The script's own `ext_resource` (with its `uid=` attribute) is allowed; any second `ext_resource` fails.
- The record-script allowlist for `[sub_resource` is a constant in the test, empty unless a record script legitimately embeds one (none in the migrated set). An entry needs a reason comment.
- It complements the catalog's load-time rejection of Resource-typed exports (content-catalog story 015): that check catches a schema that *allows* a link, this one catches a value that *is* a path inside an allowed `String` field (e.g. `sprite_set_id = "res://art/clerk.png"`).
- Fixture `.tres` files for the failing cases live under `tests/unit/battle/fixtures/no_paths/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/content-catalog/story-015-structure-validation.md`: rejecting Resource-typed exports at load.
- Story 035: the `src/battle/` hardcoded-content lint.

---

## Files

- `tests/unit/battle/battle_migrated_records_no_paths_test.gd`
- `tests/unit/battle/fixtures/no_paths/…` (one bad fixture per failing pattern, one passing `0.5` fixture)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: pinned regexes and `ext_resource`/`sub_resource` rules (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Migrated records hold no paths.
  - Given: every `.tres` in the four (or five) directories.
  - When: scanned.
  - Then: no matches; exactly one Script `ext_resource` under `res://src/data/records/`; no unlisted `[sub_resource`.
  - Edge cases: a fixture `.tres` with `sprite_set_id = "res://a.png"` fails. One with `low_hp_threshold = 0.5` passes. One with a second `ext_resource` fails. The scan reads source files only (CI), and is noted as not valid on exported binaries.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_migrated_records_no_paths_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-013-author-faction-records.md`, `story-014-author-enemy-named-attack-moves.md`, `story-015-author-bureaucratia-enemies.md`, `story-016-author-megacorp-enemies.md`, `story-017-author-faction-rule-records.md`, `story-018-author-squad-special-moves.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
