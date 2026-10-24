# Story 028: The five `SquadSpecials` factories build their Moves from the squad-special records through `MoveAdapter`, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006`, `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 4: "update `src/battle/squad/specials.gd`'s factories the same way. Re-run the Step 0 characterization tests again")
**ADR Decision Summary**: The specials' factories keep their public names and become adapters over the provisional squad-special Move records.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects."
- Required: "The five migrated EffectDescriptor types are … provisional until Quirk State System is designed."
- Guardrail: construction-time only.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 4, scoped to this story:*

- [ ] GIVEN the catalog READY, WHEN `make_speak_to_the_manager()`, `make_family_meal()`, `make_appetizer()`, `make_viral_stunt()` and `make_home_run()` run, THEN each returns `MoveAdapter.from_record()` of its record, and story 009's gate passes (002, 005 and 008 green, unchanged).

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 4:*

- The effect helpers (`apply_stun`, `apply_vulnerable`, and the heal helpers until ADR-0007 Step 2 removes them) stay. They're behaviour, not data.
- `HEAL_ATTACK_SCALE` is a Stats tuning constant that moves to `StatsConfig.heal_attack_scale` with ADR-0007 Step 2, not here (see story 032).
- The public factory names stay. They're the specials' API, and ADR-0001 keeps them as adapters; nothing in ADR-0011 deletes them.
- Viral Stunt's `effect_rounds` comes from the descriptor's `rounds` key (story 018). STUN/DAMAGE_DEBUFF have no `power` key; the adapter gives 0.
- **Seam edit:** none (`seam.move(id)` for specials already calls the factories).
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 032: deleting the specials' constants.
- Story 033: `apply_stun()` reading `is_boss` directly.
- The Stats epic: `HEAL_ATTACK_SCALE` and the heal helpers.

---

## Files

- `src/battle/squad/specials.gd` (five factory bodies)
- `tests/unit/battle/battle_move_adapter_test.gd` (specials cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Factories return adapted records; the gate passes.
  - Given: the catalog READY on `res://data`.
  - When: each of the 5 factories runs.
  - Then: it returns a Move whose fields equal `MoveAdapter.from_record(catalog.get_record(&"move", id))` field by field.
  - Edge cases: `effect_rounds` comes from `rounds` (2). Story 009's gate passes (002, 005, 008).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_move_adapter_test.gd` (specials cases) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-018-author-squad-special-moves.md`, `story-023-move-record-adapter.md`
- Unlocks: `production/epics/content-migration/story-030-delete-bureaucratia-constants.md`
