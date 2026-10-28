# Story 014: The nine enemy named attacks exist as Move records whose name, target type, cost and `damage` power equal the shipped `_named_attack()` values

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-content-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 2: "their named attacks as `Move` records, keyed by `id` not `display_name`"). Also ADR-0011: Faction Rule Modifiers (§5, named attacks table).
**ADR Decision Summary**: Each enemy named attack becomes a Move record carrying one `damage` EffectDescriptor. The catalog stores descriptors uninterpreted; only their owner reads them.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `Array[Dictionary]` exports round-trip in `.tres`; compare with deep equality (`==` on Arrays of Dictionaries compares values).

**Control Manifest Rules (this layer)**:
- Required: "EffectDescriptors (`effects` fields) are stored as plain `Array[Dictionary]` (`{type, ...params}`)."
- Required: "Attack and Defend stay code-side factories" (no `move_attack`/`move_defend` records).
- Forbidden: "Never put logic in a record class."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 2 and ADR-0011 §5, scoped to this story:*

- [ ] GIVEN `data/moves/move_{pen_jab,red_tape,late_fee,mass_audit,final_notice,laser_scan,upsell,layoffs,hostile_takeover}.tres`, WHEN loaded, THEN each has the shipped `display_name`, `target_type = single_enemy`, `cost = 0`, and `effects` deep-equals `[{"type": "damage", "power": N}]` with N from `CharacterizationExpected.NAMED_ATTACKS[id].power` (5, 10, 16, 8, 18, 11, 6, 8, 18 respectively); the record returned by a READY catalog has `effects` deep-equal to the raw `.tres` value (no keys added, removed or reordered); and a grep test finds no `power` token in `src/data/**/*.gd`.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 2, the draft's Q4 resolution and the QA gate (RC-3):*

- **Content is moved as-is and never retuned.** Final Notice stays 18 and Mass Audit 8 (the open Supervisor balance question stays open).
- **Effect type (Q4).** Named attacks carry `[{type = "damage", power = N}]`; the adapter (story 023) maps `damage` → `Category.ATTACK`. If readiness picks a different type name, only this story and 023 change.
- Mass Audit and Layoffs stay `single_enemy`. The rule makes them hit everyone by emitting one action per member. Changing them to a party target would be a behaviour change dressed as data.
- `animation_id` and `flavor_text`: Rule 1 fields with no shipped value. Leave them empty if optional. If structure validation (content-catalog story 015) makes a text field required non-empty, use the GDD's placeholder convention and record it. Don't invent flavour copy (writer's domain).
- TR-content-006: the catalog stores the descriptors uninterpreted. The catalog-copy vs raw-load comparison and the `src/data/` grep make that a test.
- **Expected values (RC-3).** Names, powers and costs are asserted against the frozen `CharacterizationExpected`; record-only values (IDs, `target_type` string) go in `MigratedRecordsExpected` (not under story 009's gate).
- Records go under `data/moves/<id>.tres`, reference their script under `src/data/records/` by path, and are never written by code at runtime. Cases go in the shared `battle_migrated_records_test.gd`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: the squad-special Move records.
- Story 023: the move adapter that reads these.
- Story 010: registering the `damage` type.

---

## Files

- `data/moves/move_pen_jab.tres`, `move_red_tape.tres`, `move_late_fee.tres`, `move_mass_audit.tres`, `move_final_notice.tres`, `move_laser_scan.tres`, `move_upsell.tres`, `move_layoffs.tres`, `move_hostile_takeover.tres`
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (named-attack block)
- `tests/unit/battle/battle_migrated_records_test.gd` (named-attack cases)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: non-circular descriptor equality, catalog-vs-raw comparison, `src/data/` grep). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Nine named-attack records, stored uninterpreted.
  - **Test: nine records.**
    - Given: the nine `.tres` files.
    - Then: name, `target_type == "single_enemy"`, `cost == 0`, and `effects == [{"type": "damage", "power": N}]` with N from the frozen fixture.
    - Edge cases: Mass Audit and Layoffs stay `single_enemy`. There are no `move_attack` or `move_defend` files.
  - **Test: uninterpreted.**
    - Given: a READY catalog on `res://data` and the raw `.tres` load.
    - Then: the catalog copy's `effects` deep-equals the raw value; a grep of `src/data/**/*.gd` finds no `power` token.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the named-attack cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-005-characterize-moves-damage.md`, `story-010-register-migrated-effect-types.md`; `production/epics/content-catalog/story-015-structure-validation.md`
- Unlocks: `production/epics/content-migration/story-015-author-bureaucratia-enemies.md`, `story-017-author-faction-rule-records.md`, `story-023-move-record-adapter.md`

## Completion Notes
**Completed**: 2026-10-28
**Criteria**: 1/1 passing
**Deviations**: Implemented together with stories 015 and 017 (beyond this story's own declared dependencies) because this story's own AC needs a genuinely READY catalog on `res://data`, which depends on both. Smoke report (`production/qa/smoke-2026-10-23.md`) predates these files; re-run `/smoke-check`.
**Test Evidence**: `tests/unit/battle/battle_migrated_records_test.gd` — exists and passes (full suite: 313/313, 0 errors, 0 failures, 0 orphans; direct probe confirms `res://data` reaches READY)
**Reviewed by**: `/code-review` (self-invoked this session, covering stories 014/015/017 together) — APPROVED
