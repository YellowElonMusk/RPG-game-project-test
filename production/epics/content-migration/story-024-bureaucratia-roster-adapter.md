# Story 024: `make_clerk()` and `make_supervisor()` build their Combatants from the `enemy_clerk` and `enemy_supervisor` records, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 3: "the public API … stays the same shape. Re-run the Step 0 characterization tests"). Also ADR-0011: Faction Rule Modifiers (§5 `Combatant.record_id`; Migration Step 3).
**ADR Decision Summary**: The roster factories keep their shape but become adapters: each reads its Enemy record and builds a new runtime `Combatant`, tagged with the record ID for identity only.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. A new trailing constructor parameter with a default keeps every existing `Combatant.new(...)` call valid.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects."
- Required: "Consumers copy a record's values into their own runtime objects (`Combatant`, `Move`) at construction time."
- Forbidden (*Core*): "Nothing in `src/battle/stats/` may reference … any other Feature type" (the adapter lives in `src/battle/`, not `stats/`).
- Guardrail: construction-time only.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 3, scoped to this story:*

- [ ] GIVEN the catalog READY on `res://data`, WHEN `BureaucratiaRule.make_clerk()` and `make_supervisor()` run, THEN each returns a new `Combatant` copied from its Enemy record with `record_id` set to the record ID, and story 009's gate passes (003, 006 and 008 green, unchanged).

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 3 and ADR-0011 §5:*

- `src/battle/enemy_adapter.gd` (`class_name EnemyAdapter`, `static func from_record(record: EnemyData) -> Combatant`) is shared with stories 025 and 029.
- `record_id` on `Combatant`: add it only if ADR-0011 Step 3 hasn't; trailing defaulted constructor parameter, immutable after construction. It is identity only; the resolver never reads it (ADR-0007 §0 annotation).
- The constants stay in the file until story 030 deletes them; they're unused after this story. Don't delete them here: one criterion per story, and 030's grep is the evidence for deletion.
- An unknown ID can't happen with shipped data, but the adapter must fail loudly (`push_error` and `null`; `last_lookup_error == &"missing_id"`). **Never fall back to the constants**: a silent fallback would make story 009's gate meaningless.
- **Seam edit:** add `BattleContentSeam.ensure_catalog()` (unless story 023 already did): it runs `ContentBootstrap.run(ContentCatalog)` once per test process (a no-op once not UNLOADED), and every seam builder calls it first. It is a test-harness call, not production lazy-loading ("Never lazy-load the catalog on the first lookup"); production factories never trigger a load and fail loudly if the catalog isn't READY.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged. Editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.
- Content is moved as-is: the Supervisor stays 110/15/10/9.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 025: the MegaCorp factories.
- Story 030: deleting the Bureaucratia constants.
- Story 034: deleting the factories and switching callers.

---

## Files

- `src/battle/enemy_adapter.gd` (`class_name EnemyAdapter`)
- `src/battle/factions/bureaucratia.gd` (factory bodies)
- `src/battle/combatant.gd` (`record_id`, only if ADR-0011 Step 3 hasn't added it)
- `tests/unit/battle/helpers/battle_content_seam.gd` (seam edit: `ensure_catalog()`)
- `tests/unit/battle/battle_enemy_adapter_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Factories read records; the gate passes.
  - Given: the catalog READY on `res://data`.
  - When: `make_clerk()` / `make_supervisor()`.
  - Then: new Combatants whose fields equal the records, with `record_id` `enemy_clerk` / `enemy_supervisor`.
  - Edge cases: `EnemyAdapter.from_record(null)` and an unknown ID give `push_error` + `null` and never fall back to the constants. Two calls are not the same instance. Story 009's gate passes (003, 006, 008).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_enemy_adapter_test.gd` — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-015-author-bureaucratia-enemies.md`, `story-021-migrated-set-validates-clean.md`
- Unlocks: `production/epics/content-migration/story-025-megacorp-roster-adapter.md`, `story-030-delete-bureaucratia-constants.md`, `story-034-delete-roster-factories.md`
