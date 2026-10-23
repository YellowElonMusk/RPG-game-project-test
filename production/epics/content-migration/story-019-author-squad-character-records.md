# Story 019: The four squad misfits exist as Character records whose stat blocks and move lists equal the agreed source, unretuned

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: user decision Q1 — migrate the prototype's iteration-3 squad stat blocks unretuned, or drop this story; criteria to be revised (QA: INADEQUATE as drafted) once decided
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-content-011` (to be re-checked when the criterion is revised; QA found the same F1-range mis-mapping on 015/016)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (EffectDescriptor adapter, `CharacterData`); GDD Rule 1 (Character)
**ADR Decision Summary**: Characters are records with ID-only references to their moves and nation. EPIC.md says "records for the existing squad", but no squad-character factory exists in `src/`; the only full stat blocks are in the throwaway prototype.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Load records in tests with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`.

**Control Manifest Rules (this layer)**:
- Required: "One record = one `.tres` file at `data/[type_plural]/[id].tres`; the filename without extension must equal the record's `id`."
- Required: "Every required field has an enforced validity rule."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference."
- Guardrail: none.

---

## Acceptance Criteria

*Draft criterion, **to be revised once Q1 is decided** (QA verdict INADEQUATE: it is conditional on an unmade decision):*

- [ ] GIVEN `data/characters/char_{karen,michelin_chef,florida_man,baguette_thrower}.tres`, WHEN loaded, THEN each `stat_block` equals the agreed source (recommended: prototype iteration 3: 34/12/12/9/11, 30/14/11/7/10, 38/10/14/8/12, 32/12/15/7/13), `move_ids` lists its specials (Karen: `move_speak_to_the_manager`; Chef: `move_appetizer`, `move_family_meal`; Florida Man: `move_viral_stunt`; Baguette Thrower: `move_home_run`), and every stat is inside its F1 range.

---

## Implementation Notes

*From the draft's Q1 and the QA gate:*

- **The blocker (Q1).** No squad character exists in `src/`, only in `prototypes/battle-concept/battle.gd:192–206`. Every shipped squad is built inline as `"Hero A"`/`"Hero B"` in the demos and the harness. Creating `char_*` records would bring *new* content into the game from a throwaway prototype, which conflicts with "moved as-is from code". Recommended if approved: source the four stat blocks from the prototype's iteration 3 (the values the specials were playtested with, and the ones `specials.gd:21` already quotes for Karen), with no retuning. Otherwise delete this story; story numbers are IDs, so nothing is renumbered.
- **What the revised criterion must name (QA).** The source lines (`prototypes/battle-concept/battle.gd` iteration 3), and for each sourceless Rule 1 field a value or "left empty, not in `REQUIRED_FIELDS`": `nation_id` (→ a `human_nation` Faction; **none exists**, so four nation records would be new content), `archetype_line`, `signature_move_id` (Leveling & Loyalty, not designed), `sprite_set_id`, `portrait_id`. It must also state whether the four `human_nation` Faction records are in scope. Drop the F1-range clause as on 015/016 (range checks belong to the owners' validators).
- No runtime caller reads character records: squads are built by callers (`ChapterFlow` takes `squad` as a parameter). Wiring a squad from records belongs to Game State's Battle mode / New Game, not here.
- Landing this story removes the five `move_*` unreferenced warnings from story 021's expected-warnings list.
- Record-only expected values would go in `MigratedRecordsExpected` (RC-3). Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: the special Move records.
- Game State (`production/epics/game-state-scene-flow/EPIC.md`): building squads from Character records.
- Story 035: the demo/harness squad allowlist (Q8).

---

## Files

- `data/characters/char_karen.tres`, `char_michelin_chef.tres`, `char_florida_man.tres`, `char_baguette_thrower.tres`
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (character block)
- `tests/unit/battle/battle_migrated_records_test.gd` (character cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict INADEQUATE — contingent spec only, to be rewritten once Q1 is decided). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1 (contingent)**: Four characters.
  - Given: the approved source.
  - Then: `stat_block` equals the source lines (34/12/12/9/11, 30/14/11/7/10, 38/10/14/8/12, 32/12/15/7/13), `move_ids` equals the specials list, and the sourceless fields are as decided.
  - Edge cases: landing it removes story 021's five expected `move_*` warnings.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the character cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-018-author-squad-special-moves.md`; user decision Q1
- Unlocks: None in this epic (no runtime reader)
